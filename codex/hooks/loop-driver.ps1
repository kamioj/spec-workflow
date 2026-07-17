#!/usr/bin/env pwsh
# Codex Stop-event driver for $spec-loop (pwsh twin of loop-driver.sh -- keep both in
# sync; the shared fixtures are the sync contract).
# Codex contract (SCHEMA.md, re-probed on codex-cli 0.144.3, 2026-07-17): re-inject =
# stdout {"decision":"block","reason":...} + exit 0 -- the reason is fed back as the next
# turn's input. {"systemMessage":...} on allow is best-effort. cwd comes from stdin JSON.
# stop_hook_active is deliberately NOT an exit condition; the loop is bounded by ledger
# state only (final acceptance may overrun the round cap exactly once). Write ownership:
# loop.md model-only, .loop-state driver-only (plus the documented cold-start/resume
# session_id line). Frontmatter values tolerate a trailing "# comment"; section headings
# must be exact (first ## Acceptance section only). Output discipline: fixed literals +
# driver-computed integers only. KEEP THE REINJECT TEMPLATES IN SYNC with
# core/commands/loop.md (Round protocol / Final acceptance) and both twins.
# Fail direction: any doubt -> exit 0, loop ends.

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

    # frontmatter value: first match, strip trailing "# comment", trim whitespace
    function FmGet([string]$text, [string]$key) {
        if ($text -match "(?m)^${key}:\s*([^`r`n]*)$") {
            return ($Matches[1] -replace '#.*$', '').Trim()
        }
        return ''
    }

    # ---- 1. locate exactly one running loop ledger (cache content: no double read) ----
    $running = @()
    $ledger = $null
    foreach ($d in (Get-ChildItem $changesDir -Directory -ErrorAction SilentlyContinue | Where-Object { $_.Name -ne 'archive' })) {
        $lp = Join-Path $d.FullName 'loop.md'
        if (Test-Path $lp) {
            $txt = Get-Content $lp -Raw -Encoding UTF8
            if ((FmGet $txt 'status') -eq 'running') {
                $running += $d.FullName
                $ledger = $txt
            }
        }
    }
    if ($running.Count -ne 1) { exit 0 }
    $change = $running[0]
    $statePath = Join-Path $change '.loop-state'

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
    function TruncCsv([string]$csv, [int]$k) {
        if ([string]::IsNullOrEmpty($csv)) { return $csv }
        $parts = $csv.Split(',')
        if ($parts.Count -le $k) { return $csv }
        return ($parts[($parts.Count - $k)..($parts.Count - 1)] -join ',')
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

    # ---- 3. numeric validity; no_progress_fuse must be >= 1 (0 = vacuous-truth fuse) ----
    $maxRounds = FmGet $ledger 'max_rounds'
    $fuseN = FmGet $ledger 'no_progress_fuse'
    if (-not $fuseN) { $fuseN = '3' }
    foreach ($v in @($maxRounds, $fuseN, $rounds, $retros)) {
        if ($v -notmatch '^[0-9]+$') {
            AllowNotice 'SPEC-LOOP halted: ledger corrupt -- max_rounds / no_progress_fuse in loop.md (or the .loop-state counters) is not a plain integer. Fix the frontmatter, then resume with $spec-loop.'
        }
    }
    if ([int]$fuseN -lt 1) {
        AllowNotice 'SPEC-LOOP halted: ledger corrupt -- no_progress_fuse must be an integer >= 1 (0 would blow the fuse unconditionally on round 2). Fix the frontmatter, then resume with $spec-loop.'
    }

    # ---- acceptance counts: FIRST exact "## Acceptance" section only ----
    $acc = [regex]::Match($ledger, '(?ms)^## Acceptance\s*?$(.*?)(?=^## |\z)').Groups[1].Value
    $unchecked = [regex]::Matches($acc, '(?m)^- \[ \]').Count
    $checked = [regex]::Matches($acc, '(?m)^- \[[xX]\]').Count

    # ---- 4. acceptance section unrecognized -> loud stop ----
    if ($unchecked -eq 0 -and $checked -eq 0) {
        AllowNotice 'SPEC-LOOP halted: ledger corrupt -- no checkbox found under an exact ## Acceptance heading in the running loop.md (heading variants are not recognized). Fix the ledger per loop-spec, then resume with $spec-loop.'
    }

    # ---- 5. acceptance met -> final acceptance (before the cap; one overrun allowed) ----
    if ($unchecked -eq 0 -and $checked -ge 1 -and [int]$rounds -le [int]$maxRounds) {
        StateWrite $session ([string]([int]$rounds + 1)) $retros $checkedHist $fpHist
        Reinject 'SPEC-LOOP: every Acceptance item in the running loop ledger (spec/changes/*/loop.md, status: running) is checked. Run the final acceptance now: dispatch the spec-verifier agent (fresh context) to independently re-verify EVERY Acceptance item against its verify: clause, report the results to the user, and only if verification holds set status: done in the loop.md frontmatter. Do not end the turn before the report is written.' 'SPEC-LOOP: acceptance checklist complete -- injecting final acceptance'
    }

    # ---- 6. round cap (primary safety mechanism) ----
    if ([int]$rounds -ge [int]$maxRounds) {
        AllowNotice 'SPEC-LOOP fuse: max_rounds reached. The loop stopped at its round budget. Review the ledger (spec/changes/*/loop.md); raise max_rounds and resume with $spec-loop, or close out with $spec-archive.'
    }

    # ---- 7. retrospect gate ----
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

    # ---- 8. no-progress fuse (fingerprint = HEAD + working tree; explicit exit codes) ----
    $fp = 'na'
    try {
        $null = git -C $cwd rev-parse --is-inside-work-tree 2>$null
        if ($LASTEXITCODE -eq 0) {
            $porc = (git -C $cwd status --porcelain 2>$null | Out-String)
            if ($LASTEXITCODE -eq 0) {
                $headSha = (git -C $cwd rev-parse HEAD 2>$null | Out-String).Trim()
                if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrEmpty($headSha)) { $headSha = 'none' }
                $md5 = [System.Security.Cryptography.MD5]::Create()
                $fp = [System.BitConverter]::ToString($md5.ComputeHash([System.Text.Encoding]::UTF8.GetBytes("$headSha`n$porc"))).Replace('-', '').Substring(0, 16)
            }
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
            AllowNotice 'SPEC-LOOP fuse: no measurable progress for no_progress_fuse consecutive rounds (acceptance checkbox count and worktree+HEAD fingerprint both unchanged). The loop stopped early. Review the ledger Lessons, adjust the plan or the acceptance list, then resume with $spec-loop.'
        }
    }

    # ---- 9. continue (histories truncated to FUSE_N on write; round number from the
    #         already-computed block count -- no second full-text scan) ----
    $next = $roundBlocks.Count + 1
    $ch = if ($checkedHist) { TruncCsv "$checkedHist,$checked" ([int]$fuseN) } else { [string]$checked }
    $fh = if ($fpHist) { TruncCsv "$fpHist,$fp" ([int]$fuseN) } else { $fp }
    StateWrite $session ([string]([int]$rounds + 1)) '0' $ch $fh
    Reinject "SPEC-LOOP: start round $next of $maxRounds. Read the running loop ledger (spec/changes/*/loop.md, status: running) in full -- Acceptance, the latest Retrospect, Lessons. Pick exactly ONE next item from the last retrospect plan (or the first unchecked Acceptance item). Search the ledger and the codebase before assuming anything is unimplemented. Then implement it, verify through the spec-verifier agent (self-review does not count), check off any Acceptance item only with verifier evidence, and write this round's ### Round $next section with a non-empty #### Retrospect before ending the turn. To pause the loop instead, set status: paused in loop.md frontmatter." "SPEC-LOOP: round $next of $maxRounds injected"
} catch {
    [Console]::Error.WriteLine("SPEC-LOOP driver internal error (fail-open, loop ends): $_")
    exit 0
}
