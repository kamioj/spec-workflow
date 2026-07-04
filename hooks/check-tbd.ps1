#!/usr/bin/env pwsh
# Pre-check for /spec:propose: research.md's ## Open [TBD] section must be empty
# Trigger: UserPromptSubmit hook
# Behavior: when the user input INVOKES /spec:propose (at the start of a line -- merely
# mentioning the command in a question must not trigger the gate), scan research.md;
# if it contains [TBD], exit 2 to block

# UTF-8 stdin/stdout
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

    # Only trigger on invocation (line start), not on mention ("what does /spec:propose do?")
    if ($userPrompt -notmatch '(?m)^\s*/spec:propose') { exit 0 }

    # Find the un-archived change (spec/changes/<name>/, excluding archive)
    $changesDir = Join-Path $cwd 'spec' | Join-Path -ChildPath 'changes'
    if (-not (Test-Path $changesDir)) { exit 0 }

    $changes = Get-ChildItem $changesDir -Directory -ErrorAction SilentlyContinue |
               Where-Object { $_.Name -ne 'archive' }

    if (-not $changes -or $changes.Count -eq 0) {
        [Console]::Error.WriteLine('SDD: no active change. Start with /spec:research <direction>')
        exit 2
    }

    if ($changes.Count -gt 1) {
        $names = ($changes | ForEach-Object { $_.Name }) -join ', '
        [Console]::Error.WriteLine("SDD: multiple active changes detected ($names). This workflow assumes a single active change -- /spec:archive the rest (or clean them up) before /spec:propose")
        exit 2
    }

    foreach ($change in $changes) {
        $researchPath = Join-Path $change.FullName 'research.md'
        if (-not (Test-Path $researchPath)) {
            [Console]::Error.WriteLine("SDD: $($change.Name) is missing research.md. Run /spec:research <direction> first")
            exit 2
        }

        $content = Get-Content $researchPath -Raw -Encoding UTF8

        # Strip the ## Decided section (its "source [TBD-N]" references are resolved citations, not open items), then scan the rest for unresolved [TBD-N]
        # Backstop: even if the LLM omits the ## Open [TBD] heading, or buries [TBD-N] in another section, this still catches it (the hard constraint can't be silently bypassed)
        $scanText = $content -replace '(?ms)^##\s*Decided[\s\S]*?(?=^##\s+|\z)', ''
        if ($scanText -match '\[TBD-\d+\]') {
            [Console]::Error.WriteLine("SDD: research.md ($($change.Name)) has unresolved [TBD] decision points. Run /spec:ask to resolve them first")
            exit 2
        }
    }

    exit 0
} catch {
    # A bug in the hook itself must not block the flow
    [Console]::Error.WriteLine("SDD check-tbd hook internal error (fail-open): $_")
    exit 0
}
