#!/usr/bin/env pwsh
# Pre-check for /spec:apply: proposal.md must carry the APPROVED marker
# Trigger: UserPromptSubmit hook
# Behavior: when the user input contains /spec:apply, scan proposal.md; if there's no APPROVED marker, exit 2 to block

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

    if ($userPrompt -notmatch '/spec:apply') { exit 0 }

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

        # APPROVED marker: only the <!-- APPROVED: ... --> comment form written by apply counts (bare text / headings don't, to avoid the body text being misread as approval)
        $approvedPattern = '(?i)<!--\s*APPROVED\s*[:>]'

        if ($content -notmatch $approvedPattern) {
            [Console]::Error.WriteLine("SDD: proposal.md ($($change.Name)) has no APPROVED marker. Run /spec:propose through the HARD GATE first, then run /spec:apply once satisfied (apply auto-appends the APPROVED marker)")
            exit 2
        }
    }

    exit 0
} catch {
    [Console]::Error.WriteLine("SDD check-gate hook internal error (fail-open): $_")
    exit 0
}
