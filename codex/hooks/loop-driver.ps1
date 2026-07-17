#!/usr/bin/env pwsh
# Codex Stop-event driver for $spec-loop (pwsh twin of loop-driver.sh -- keep both in
# sync; the shared fixtures are the sync contract).
# Codex contract (SCHEMA.md, re-probed on codex-cli 0.144.3, 2026-07-17): re-inject =
# stdout {"decision":"block","reason":...} + exit 0 -- the reason is fed back as the next
# turn's input. {"systemMessage":...} on allow is best-effort. cwd comes from stdin JSON.
# stop_hook_active is deliberately NOT an exit condition; the loop is bounded by ledger
# state only (round cap / no-progress fuse / retro-refusal cap). Write ownership: loop.md
# model-only, .loop-state driver-only. Output discipline: fixed literals + driver-computed
# integers only. Fail direction: any doubt -> exit 0, loop ends.

[Console]::InputEncoding = [System.Text.Encoding]::UTF8
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$ErrorActionPreference = 'Continue'

function Reinject([string]$reason, [string]$msg) {
    @{ decision = 'block'; reason = $reason; systemMessage = $msg } | ConvertTo-Json -Compress | Write-Output
    exit 0
}
function AllowNotice([string]$msg) {
    @{ systemMessage = $msg } | ConvertTo-Json -Compress | Write-Output
    exit 0
}

try {
    $stdin = [Console]::In.ReadToEnd()
    if ([string]::IsNullOrWhiteSpace($stdin)) { exit 0 }
    $data = $stdin | ConvertFrom-Json

    $cwd = $data.cwd
    if ([string]::IsNullOrWhiteSpace($cwd)) { exit 0 }
    $changesDir = Join-Path $cwd 'spec' | Join-Path -ChildPath 'changes'
    if (-not (Test-Path $changesDir)) { exit 0 }

    # ---- 1. locate exactly one running loop ledger ----
    $running = @()
    foreach ($d in (Get-ChildItem $changesDir -Directory -ErrorAction SilentlyContinue | Where-Object { $_.Name -ne 'archive' })) {
        $lp = Join-Path $d.FullName 'loop.md'
        if (Test-Path $lp) {
            $txt = Get-Content $lp -Raw -Encoding UTF8
            if ($txt -match '(?m)^status:\s*running\s*$') { $running += $d.FullName }
        }
    }
    if ($running.Count -ne 1) { exit 0 }
    $change = $running[0]
    $ledgerPath = Join-Path $change 'loop.md'
    $statePath = Join-Path $change '.loop-state'
    $ledger = Get-Content $ledgerPath -Raw -Encoding UTF8

    # ---- state (driver-owned key=value file) ----
    $state = @{}
    if (Test-Path $statePath) {
        foreach ($line in (Get-Content $statePath -Encoding UTF8)) {
            $i = $line.IndexOf('=')
            if ($i -gt 0) { $state[$line.Substring(0, $i)] = $line.Substring($i + 1) }
        }
    }
    function StateGet([string]$k, [string]$def) {
        if ($state.ContainsKey($k) -and -not [string]::IsNullOrEmpty($state[$k])) { return $state[$k] }
        return $def
    }
    function StateWrite([string]$sess, [string]$rounds, [string]$retros, [string]$ch, [string]$fh) {
        $body = "session_id=$sess`nrounds_injected=$rounds`nretro_reinjects=$retros`nchecked_history=$ch`ntree_fp_history=$fh`n"
        Set-Content -Path $statePath -Value $body -Encoding UTF8 -NoNewline
    }

    # ---- 2. session guard ----
    $stdinSession = if ($null -ne $data.session_id) { [string]$data.session_id } else { '' }
    $session = StateGet 'session_id' ''
    if ($session -and $stdinSession -and ($session -ne $stdinSession)) { exit 0 }
    if (-not $session) { $session = $stdinSession }

    $rounds = StateGet 'rounds_injected' '0'
    $retros = StateGet 'retro_reinjects' '0'
    $checkedHist = StateGet 'checked_history' ''
    $fpHist = StateGet 'tree_fp_history' ''

    # ---- 3. numeric validity (non-integer would silently disarm the cap) ----
    $maxRounds = if ($ledger -match '(?m)^max_rounds:\s*(\S+)\s*$') { $Matches[1] } else { '' }
    $fuseN = if ($ledger -match '(?m)^no_progress_fuse:\s*(\S+)\s*$') { $Matches[1] } else { '3' }
    foreach ($v in @($maxRounds, $fuseN, $rounds, $retros)) {
        if ($v -notmatch '^[0-9]+$') {
            AllowNotice 'SPEC-LOOP halted: ledger corrupt -- max_rounds / no_progress_fuse in loop.md (or the .loop-state counters) is not a plain integer. Fix the frontmatter, then resume with $spec-loop.'
        }
    }

    # ---- 4. round cap (primary safety mechanism) ----
    if ([int]$rounds -ge [int]$maxRounds) {
        AllowNotice 'SPEC-LOOP fuse: max_rounds reached. The loop stopped at its round budget. Review the ledger (spec/changes/*/loop.md); raise max_rounds and resume with $spec-loop, or close out with $spec-archive.'
    }

    # ---- acceptance section counts ----
    $acc = [regex]::Match($ledger, '(?ms)^## Acceptance\s*?$(.*?)(?=^## |\z)').Groups[1].Value
    $unchecked = [regex]::Matches($acc, '(?m)^- \[ \]').Count
    $checked = [regex]::Matches($acc, '(?m)^- \[[xX]\]').Count

    # ---- 5. acceptance met -> inject final acceptance (counts toward the cap) ----
    if ($unchecked -eq 0 -and $checked -ge 1) {
        StateWrite $session ([string]([int]$rounds + 1)) $retros $checkedHist $fpHist
        Reinject 'SPEC-LOOP: every Acceptance item in the running loop ledger (spec/changes/*/loop.md, status: running) is checked. Run the final acceptance now: dispatch the spec-verifier agent (fresh context) to independently re-verify EVERY Acceptance item against its verify: clause, report the results to the user, and only if verification holds set status: done in the loop.md frontmatter. Do not end the turn before the report is written.' 'SPEC-LOOP: acceptance checklist complete -- injecting final acceptance'
    }

    # ---- 6. retrospect gate ----
    $roundBlocks = [regex]::Matches($ledger, '(?ms)^### Round .*?(?=^### Round |^## |\z)')
    $retroOk = $false
    if ($roundBlocks.Count -ge 1) {
        $last = $roundBlocks[$roundBlocks.Count - 1].Value
        $retroBody = [regex]::Match($last, '(?ms)^#### Retrospect\s*?$(.*?)(?=^#### |\z)').Groups[1].Value
        if ($retroBody -match '\S') { $retroOk = $true }
    }
    if (-not $retroOk) {
        if ([int]$retros -ge 2) {
            AllowNotice 'SPEC-LOOP halted: the retrospect for the current round was still missing after 2 re-injections. This is a refusal-to-retrospect stop, NOT a normal fuse -- inspect the ledger and the last round before resuming with $spec-loop.'
        }
        StateWrite $session $rounds ([string]([int]$retros + 1)) $checkedHist $fpHist
        Reinject 'SPEC-LOOP: the current round in the running loop ledger (spec/changes/*/loop.md, status: running) has no non-empty #### Retrospect -- create the round section (### Round N) if it is missing entirely, then write its retrospect: the lesson learned (add durable ones to ## Lessons) plus the next-round plan. The loop will not advance without it. Then end the turn.' 'SPEC-LOOP: retrospect missing -- re-injecting (not counted as a new round)'
    }

    # ---- 7. no-progress fuse (mechanical signals only) ----
    $fp = 'na'
    try {
        $null = git -C $cwd rev-parse --is-inside-work-tree 2>$null
        if ($LASTEXITCODE -eq 0) {
            $txt = (git -C $cwd status --porcelain 2>$null | Out-String)
            $md5 = [System.Security.Cryptography.MD5]::Create()
            $fp = [System.BitConverter]::ToString($md5.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($txt))).Replace('-', '').Substring(0, 16)
        }
    } catch { $fp = 'na' }
    function TailAllEqual([string]$csv, [int]$k, [string]$cur) {
        if ([string]::IsNullOrEmpty($csv)) { return $false }
        $parts = $csv.Split(',')
        if ($parts.Count -lt $k) { return $false }
        for ($i = $parts.Count - $k; $i -lt $parts.Count; $i++) {
            if ($parts[$i] -ne $cur) { return $false }
        }
        return $true
    }
    if ($checkedHist) {
        $cStale = TailAllEqual $checkedHist ([int]$fuseN) ([string]$checked)
        $fStale = $true
        if ($fp -ne 'na') { $fStale = TailAllEqual $fpHist ([int]$fuseN) $fp }
        if ($cStale -and $fStale) {
            AllowNotice 'SPEC-LOOP fuse: no measurable progress for no_progress_fuse consecutive rounds (acceptance checkbox count and worktree fingerprint both unchanged). The loop stopped early. Review the ledger Lessons, adjust the plan or the acceptance list, then resume with $spec-loop.'
        }
    }

    # ---- 8. continue: next round ----
    $roundCount = [regex]::Matches($ledger, '(?m)^### Round ').Count
    $next = $roundCount + 1
    $ch = if ($checkedHist) { "$checkedHist,$checked" } else { [string]$checked }
    $fh = if ($fpHist) { "$fpHist,$fp" } else { $fp }
    StateWrite $session ([string]([int]$rounds + 1)) '0' $ch $fh
    Reinject "SPEC-LOOP: start round $next of $maxRounds. Read the running loop ledger (spec/changes/*/loop.md, status: running) in full -- Acceptance, the latest Retrospect, Lessons. Pick exactly ONE next item from the last retrospect plan (or the first unchecked Acceptance item). Search the ledger and the codebase before assuming anything is unimplemented. Then implement it, verify through the spec-verifier agent (self-review does not count), check off any Acceptance item only with verifier evidence, and write this round's ### Round $next section with a non-empty #### Retrospect before ending the turn. To pause the loop instead, set status: paused in loop.md frontmatter." "SPEC-LOOP: round $next of $maxRounds injected"
} catch {
    [Console]::Error.WriteLine("SPEC-LOOP driver internal error (fail-open, loop ends): $_")
    exit 0
}
