#!/usr/bin/env pwsh
# Codex port of the /spec:archive gate: the change must not have bypassed the flow.
# Trigger: UserPromptSubmit hook (Codex CLI).
# Codex-specific contract (see SCHEMA.md, probe-verified on codex-cli 0.142.1):
#   - stdin field is `prompt` (same field name as Claude Code — corrected 2026-07-15)
#   - blocking = stdout {"decision":"block","reason":...} + exit 0 (exit 2 does NOT block on Codex)
#   - invocation form is `$spec-archive` (Codex skills), not `/spec:archive`
# Audits the single active change:
#   - proposal.md exists but has no APPROVED marker  -> the HARD GATE was bypassed
#   - tasks.md has unchecked "- [ ]" items           -> archiving unfinished work
#   - no proposal.md at all                          -> research-only change
# Any finding -> block with the list, UNLESS the prompt also contains "force" or
# "abandon(ed)" (deliberate override; $spec-archive records the reason in retrospect.md).
# Unlike check-tbd/check-gate, this hook does NOT block on multiple active changes --
# archiving is exactly how you get back down to one.
# fail-open: internal errors exit 0 with no stdout.

[Console]::InputEncoding = [System.Text.Encoding]::UTF8
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$ErrorActionPreference = 'Continue'

function Block([string]$reason) {
    @{ decision = 'block'; reason = $reason } | ConvertTo-Json -Compress | Write-Output
    exit 0
}

try {
    $stdin = [Console]::In.ReadToEnd()
    if ([string]::IsNullOrWhiteSpace($stdin)) { exit 0 }

    $data = $stdin | ConvertFrom-Json
    $userPrompt = $data.prompt
    $cwd = $data.cwd

    # Only trigger on invocation (line start), not on mention ("explain $spec-archive")
    if ($userPrompt -notmatch '(?m)^\s*\$spec-archive\b') { exit 0 }

    # Deliberate override: the user explicitly said force / abandoned
    if ($userPrompt -match '(?i)\b(force|abandon(ed)?)\b') { exit 0 }

    $changesDir = Join-Path $cwd 'spec' | Join-Path -ChildPath 'changes'
    if (-not (Test-Path $changesDir)) {
        Block 'SDD: no spec/changes/ directory -- nothing to archive'
    }

    $changes = Get-ChildItem $changesDir -Directory -ErrorAction SilentlyContinue |
               Where-Object { $_.Name -ne 'archive' }

    if (-not $changes -or $changes.Count -eq 0) {
        Block 'SDD: no active change -- nothing to archive'
    }

    # Multiple active changes: let it through; $spec-archive asks which one to archive
    if ($changes.Count -gt 1) { exit 0 }

    $change = $changes[0]

    # $spec-loop change: no proposal.md by design — the ledger is the flow record. Trust
    # model (0.5.1): status: done is written by the final-acceptance turn, the same class
    # of flow-moment anchor as the APPROVED marker.
    $loopPath = Join-Path $change.FullName 'loop.md'
    if (Test-Path $loopPath) {
        $loop = Get-Content $loopPath -Raw -Encoding UTF8
        $lstatus = if ($loop -match "(?m)^status:\s*([^`r`n]*)$") { ($Matches[1] -replace '#.*$', '').Trim() } else { '' }
        $lacc = [regex]::Match($loop, '(?ms)^## Acceptance\s*?$(.*?)(?=^## |\z)').Groups[1].Value
        $lunchecked = [regex]::Matches($lacc, '(?m)^- \[ \]').Count
        $lchecked = [regex]::Matches($lacc, '(?m)^- \[[xX]\]').Count
        if ($lstatus -eq 'done' -and $lunchecked -eq 0 -and $lchecked -ge 1) { exit 0 }
        $lines = @("SDD: archive blocked for '$($change.Name)' -- the loop is not finished:")
        $lines += '  - loop.md must have status: done AND a fully checked ## Acceptance list (run the final acceptance via $spec-loop)'
        $lines += 'Or archive deliberately:'
        $lines += '  "$spec-archive force"     -- archive as-is; the reason gets recorded in retrospect.md'
        $lines += '  "$spec-archive abandoned" -- drop the direction; archived as *-abandoned with ABANDONED.md'
        Block ($lines -join "`n")
    }

    $findings = @()

    $proposalPath = Join-Path $change.FullName 'proposal.md'
    if (Test-Path $proposalPath) {
        $content = Get-Content $proposalPath -Raw -Encoding UTF8
        # Same marker contract as the Claude-side hooks: only the <!-- APPROVED: --> comment form counts
        if ($content -notmatch '(?i)<!--\s*APPROVED\s*[:>]') {
            $findings += 'proposal.md has no APPROVED marker -- the HARD GATE was bypassed (code written without $spec-apply?)'
        }
    } else {
        $findings += 'no proposal.md -- research-only change (pausing or dropping a direction?)'
    }

    $tasksPath = Join-Path $change.FullName 'tasks.md'
    if (Test-Path $tasksPath) {
        $tasksContent = Get-Content $tasksPath -Raw -Encoding UTF8
        $unchecked = [regex]::Matches($tasksContent, '(?m)^\s*- \[ \]').Count
        if ($unchecked -gt 0) {
            $findings += "tasks.md has $unchecked unchecked item(s) -- archiving unfinished work"
        }
    }

    if ($findings.Count -eq 0) { exit 0 }

    $lines = @("SDD: archive blocked for '$($change.Name)' -- this change bypassed the flow:")
    foreach ($f in $findings) { $lines += "  - $f" }
    $lines += 'Fix first ($spec-apply to finish, $spec-verify to verify), or archive deliberately:'
    $lines += '  "$spec-archive force"     -- archive as-is; the reason gets recorded in retrospect.md'
    $lines += '  "$spec-archive abandoned" -- drop the direction; archived as *-abandoned with ABANDONED.md'
    Block ($lines -join "`n")
} catch {
    [Console]::Error.WriteLine("SDD check-archive hook internal error (fail-open): $_")
    exit 0
}
