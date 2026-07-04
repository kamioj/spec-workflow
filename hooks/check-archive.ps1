#!/usr/bin/env pwsh
# Pre-check for /spec:archive: the change must not have bypassed the flow
# Trigger: UserPromptSubmit hook
# Behavior: when the user input contains /spec:archive, audit the single active change:
#   - proposal.md exists but has no APPROVED marker  -> the HARD GATE was bypassed
#   - tasks.md has unchecked "- [ ]" items           -> archiving unfinished work
#   - no proposal.md at all                          -> research-only change
# Any finding -> exit 2 with the list, UNLESS the prompt also contains "force" or
# "abandon(ed)" (deliberate override; /spec:archive records the reason in retrospect.md).
# Unlike check-tbd/check-gate, this hook does NOT block on multiple active changes --
# archiving is exactly how you get back down to one.
# fail-open: internal errors exit 0.

[Console]::InputEncoding = [System.Text.Encoding]::UTF8
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$ErrorActionPreference = 'Continue'

try {
    $stdin = [Console]::In.ReadToEnd()
    if ([string]::IsNullOrWhiteSpace($stdin)) { exit 0 }

    $data = $stdin | ConvertFrom-Json
    # The UserPromptSubmit stdin JSON field is named user_prompt (not prompt)
    $userPrompt = $data.user_prompt
    $cwd = $data.cwd

    # Only trigger on invocation (line start), not on mention ("explain /spec:archive")
    if ($userPrompt -notmatch '(?m)^\s*/spec:archive') { exit 0 }

    # Deliberate override: the user explicitly said force / abandoned
    if ($userPrompt -match '(?i)\b(force|abandon(ed)?)\b') { exit 0 }

    $changesDir = Join-Path $cwd 'spec' | Join-Path -ChildPath 'changes'
    if (-not (Test-Path $changesDir)) {
        [Console]::Error.WriteLine('SDD: no spec/changes/ directory -- nothing to archive')
        exit 2
    }

    $changes = Get-ChildItem $changesDir -Directory -ErrorAction SilentlyContinue |
               Where-Object { $_.Name -ne 'archive' }

    if (-not $changes -or $changes.Count -eq 0) {
        [Console]::Error.WriteLine('SDD: no active change -- nothing to archive')
        exit 2
    }

    # Multiple active changes: let it through; /spec:archive asks which one to archive
    if ($changes.Count -gt 1) { exit 0 }

    $change = $changes[0]
    $findings = @()

    $proposalPath = Join-Path $change.FullName 'proposal.md'
    if (Test-Path $proposalPath) {
        $content = Get-Content $proposalPath -Raw -Encoding UTF8
        # Same marker contract as check-gate.ps1: only the <!-- APPROVED: --> comment form counts
        if ($content -notmatch '(?i)<!--\s*APPROVED\s*[:>]') {
            $findings += 'proposal.md has no APPROVED marker -- the HARD GATE was bypassed (code written without /spec:apply?)'
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

    [Console]::Error.WriteLine("SDD: archive blocked for '$($change.Name)' -- this change bypassed the flow:")
    foreach ($f in $findings) { [Console]::Error.WriteLine("  - $f") }
    [Console]::Error.WriteLine('Fix first (/spec:apply to finish, /spec:verify to verify), or archive deliberately:')
    [Console]::Error.WriteLine('  "/spec:archive force"     -- archive as-is; the reason gets recorded in retrospect.md')
    [Console]::Error.WriteLine('  "/spec:archive abandoned" -- drop the direction; archived as *-abandoned with ABANDONED.md')
    exit 2
} catch {
    [Console]::Error.WriteLine("SDD check-archive hook internal error (fail-open): $_")
    exit 0
}
