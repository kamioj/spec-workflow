#!/usr/bin/env pwsh
# Codex port of the /spec:propose gate: research.md's ## Open [TBD] section must be empty.
# Trigger: UserPromptSubmit hook (Codex CLI).
# Codex-specific contract (see SCHEMA.md, probe-verified on codex-cli 0.142.1):
#   - stdin field is `prompt` (Claude Code uses `user_prompt`)
#   - blocking = stdout {"decision":"block","reason":...} + exit 0 (exit 2 does NOT block on Codex)
#   - invocation form is `$spec-propose` (Codex skills), not `/spec:propose`
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

    # Only trigger on invocation (line start), not on mention ("what does $spec-propose do?")
    if ($userPrompt -notmatch '(?m)^\s*\$spec-propose\b') { exit 0 }

    $changesDir = Join-Path $cwd 'spec' | Join-Path -ChildPath 'changes'
    if (-not (Test-Path $changesDir)) { exit 0 }

    $changes = Get-ChildItem $changesDir -Directory -ErrorAction SilentlyContinue |
               Where-Object { $_.Name -ne 'archive' }

    if (-not $changes -or $changes.Count -eq 0) {
        Block 'SDD: no active change. Start with $spec-research <direction>'
    }

    if ($changes.Count -gt 1) {
        $names = ($changes | ForEach-Object { $_.Name }) -join ', '
        Block "SDD: multiple active changes detected ($names). This workflow assumes a single active change -- `$spec-archive the rest (or clean them up) before `$spec-propose"
    }

    foreach ($change in $changes) {
        $researchPath = Join-Path $change.FullName 'research.md'
        if (-not (Test-Path $researchPath)) {
            Block "SDD: $($change.Name) is missing research.md. Run `$spec-research <direction> first"
        }

        $content = Get-Content $researchPath -Raw -Encoding UTF8

        # Strip the ## Decided section (its "source [TBD-N]" references are resolved citations,
        # not open items), then scan the rest for unresolved [TBD-N]
        $scanText = $content -replace '(?ms)^##\s*Decided[\s\S]*?(?=^##\s+|\z)', ''
        if ($scanText -match '\[TBD-\d+\]') {
            Block "SDD: research.md ($($change.Name)) has unresolved [TBD] decision points. Run `$spec-ask to resolve them first"
        }
    }

    exit 0
} catch {
    # A bug in the hook itself must not block the flow
    [Console]::Error.WriteLine("SDD check-tbd hook internal error (fail-open): $_")
    exit 0
}
