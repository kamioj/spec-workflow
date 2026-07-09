#!/usr/bin/env pwsh
# Codex port of the /spec:apply gate: prerequisites must exist -- a proposal that went
# through $spec-propose (all four sections present) and a single active change.
# Trigger: UserPromptSubmit hook (Codex CLI).
# Codex-specific contract (see SCHEMA.md, probe-verified on codex-cli 0.142.1):
#   - stdin field is `prompt` (Claude Code uses `user_prompt`)
#   - blocking = stdout {"decision":"block","reason":...} + exit 0 (exit 2 does NOT block on Codex)
#   - invocation form is `$spec-apply` (Codex skills), not `/spec:apply`
#
# Deliberately NOT checked here: the <!-- APPROVED --> marker. Under the
# invocation-as-approval design, $spec-apply itself appends the marker AFTER this hook
# has fired -- requiring the marker here would deadlock the happy path.
# The marker is enforced at archive time by check-archive.
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

    # Only trigger on invocation (line start), not on mention ("what does $spec-apply do?")
    if ($userPrompt -notmatch '(?m)^\s*\$spec-apply\b') { exit 0 }

    $changesDir = Join-Path $cwd 'spec' | Join-Path -ChildPath 'changes'
    if (-not (Test-Path $changesDir)) {
        Block 'SDD: no spec/changes/ directory. Start with $spec-research -> $spec-propose'
    }

    $changes = Get-ChildItem $changesDir -Directory -ErrorAction SilentlyContinue |
               Where-Object { $_.Name -ne 'archive' }

    if (-not $changes -or $changes.Count -eq 0) {
        Block 'SDD: no active change. Start with $spec-research -> $spec-propose'
    }

    if ($changes.Count -gt 1) {
        $names = ($changes | ForEach-Object { $_.Name }) -join ', '
        Block "SDD: multiple active changes detected ($names). This workflow assumes a single active change -- `$spec-archive the rest (or clean them up) before `$spec-apply (otherwise a draft change blocks the approved one)"
    }

    foreach ($change in $changes) {
        $proposalPath = Join-Path $change.FullName 'proposal.md'
        if (-not (Test-Path $proposalPath)) {
            Block "SDD: $($change.Name) is missing proposal.md. Run `$spec-propose first"
        }

        $content = Get-Content $proposalPath -Raw -Encoding UTF8

        # A proposal that went through $spec-propose carries all four sections
        $missing = @()
        foreach ($section in '## Why', '## What', '## How', '## Risk') {
            if ($content -notmatch "(?m)^$section") { $missing += $section }
        }
        if ($missing.Count -gt 0) {
            Block "SDD: proposal.md ($($change.Name)) is missing section(s): $($missing -join ', '). Run `$spec-revise to complete it, or `$spec-propose to rewrite"
        }
    }

    exit 0
} catch {
    [Console]::Error.WriteLine("SDD check-gate hook internal error (fail-open): $_")
    exit 0
}
