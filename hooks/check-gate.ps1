#!/usr/bin/env pwsh
# Pre-check for /spec:apply: prerequisites must exist -- a proposal that went through
# /spec:propose (all four sections present) and a single active change.
# Trigger: UserPromptSubmit hook
# Behavior: when the user input INVOKES /spec:apply (at the start of a line -- merely
# mentioning the command in a question must not trigger the gate), verify prerequisites;
# missing -> exit 2 to block.
#
# Deliberately NOT checked here: the <!-- APPROVED --> marker. Under the
# invocation-as-approval design, /spec:apply itself appends the marker AFTER this hook
# has fired -- requiring the marker here would deadlock the happy path (the pre-0.2.3
# bug: propose -> gate -> /spec:apply -> blocked "no marker" -> apply never runs -> the
# marker never gets appended). The marker is an audit record: check-archive.ps1 enforces
# it at archive time, /spec:status reports it.
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

    # Only trigger on invocation (line start), not on mention ("what does /spec:apply do?")
    if ($userPrompt -notmatch '(?m)^\s*/spec:apply') { exit 0 }

    $changesDir = Join-Path $cwd 'spec' | Join-Path -ChildPath 'changes'
    if (-not (Test-Path $changesDir)) {
        [Console]::Error.WriteLine('SDD: no spec/changes/ directory. Start with /spec:research -> /spec:propose')
        exit 2
    }

    $changes = Get-ChildItem $changesDir -Directory -ErrorAction SilentlyContinue |
               Where-Object { $_.Name -ne 'archive' }

    if (-not $changes -or $changes.Count -eq 0) {
        [Console]::Error.WriteLine('SDD: no active change. Start with /spec:research -> /spec:propose')
        exit 2
    }

    if ($changes.Count -gt 1) {
        $names = ($changes | ForEach-Object { $_.Name }) -join ', '
        [Console]::Error.WriteLine("SDD: multiple active changes detected ($names). This workflow assumes a single active change -- /spec:archive the rest (or clean them up) before /spec:apply (otherwise a draft change blocks the approved one)")
        exit 2
    }

    foreach ($change in $changes) {
        $proposalPath = Join-Path $change.FullName 'proposal.md'
        if (-not (Test-Path $proposalPath)) {
            [Console]::Error.WriteLine("SDD: $($change.Name) is missing proposal.md. Run /spec:propose first")
            exit 2
        }

        $content = Get-Content $proposalPath -Raw -Encoding UTF8

        # A proposal that went through /spec:propose carries all four sections
        $missing = @()
        foreach ($section in '## Why', '## What', '## How', '## Risk') {
            if ($content -notmatch "(?m)^$section") { $missing += $section }
        }
        if ($missing.Count -gt 0) {
            [Console]::Error.WriteLine("SDD: proposal.md ($($change.Name)) is missing section(s): $($missing -join ', '). Run /spec:revise to complete it, or /spec:propose to rewrite")
            exit 2
        }
    }

    exit 0
} catch {
    [Console]::Error.WriteLine("SDD check-gate hook internal error (fail-open): $_")
    exit 0
}
