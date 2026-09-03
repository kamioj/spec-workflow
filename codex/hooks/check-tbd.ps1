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

    # Skip suspended changes and self-auditing tier dirs -- quick/fix/loop without proposal.md
    # (precedence: proposal.md wins -- an upgraded tier dir counts as a normal full change).
    $changes = Get-ChildItem $changesDir -Directory -ErrorAction SilentlyContinue |
               Where-Object {
                   $_.Name -ne 'archive' -and
                   -not (Test-Path (Join-Path $_.FullName '.paused')) -and
                   -not ((Test-Path (Join-Path $_.FullName 'quick.md')) -and -not (Test-Path (Join-Path $_.FullName 'proposal.md'))) -and
                   -not ((Test-Path (Join-Path $_.FullName 'fix.md')) -and -not (Test-Path (Join-Path $_.FullName 'proposal.md'))) -and
                   -not ((Test-Path (Join-Path $_.FullName 'loop.md')) -and -not (Test-Path (Join-Path $_.FullName 'proposal.md')))
               }

    if (-not $changes -or $changes.Count -eq 0) {
        Block "SDD: no active change under $changesDir (.paused / quick / fix / loop dirs do not count). Start with `$spec-research <direction>. Already researched one? It may sit in a DIFFERENT spec tree (another worktree / the main repo / a subproject) -- hooks only see the session cwd: move it here, or relaunch there"
    }

    if ($changes.Count -gt 1) {
        $names = ($changes | ForEach-Object { $_.Name }) -join ', '
        Block "SDD: multiple active changes detected under $changesDir ($names). This workflow assumes a single active change -- `$spec-archive the rest (or clean them up) before `$spec-propose"
    }

    foreach ($change in $changes) {
        $researchPath = Join-Path $change.FullName 'research.md'
        if (-not (Test-Path $researchPath)) {
            # Self-diagnosis: name what the gate actually saw, so a change created in a
            # different spec tree (worktree / main repo / subproject) is recognizable at a
            # glance instead of blocking with a misleading unrelated change name (0.6.4).
            $found = (Get-ChildItem $change.FullName -Force -Name -ErrorAction SilentlyContinue) -join ' '
            if ([string]::IsNullOrWhiteSpace($found)) { $found = '(empty)' }
            Block ("SDD: change '$($change.Name)' is missing research.md -- run `$spec-research <direction> first.`n" +
                   "(gate inspected $changesDir; '$($change.Name)' holds: $found. Not the change you just researched? Yours likely sits in a DIFFERENT spec tree -- another worktree / the main repo / a subproject: hooks only see the session cwd; move it here, or relaunch the session where it lives)")
        }

        $content = Get-Content $researchPath -Raw -Encoding UTF8

        # Scan ONLY the ## Open [TBD] section: [TBD-N] tokens elsewhere (Practices/Constraints/
        # Decided) are provenance citations of a decision point, not open items. List the
        # concrete IDs so the user can jump straight into $spec-ask on them.
        $openSection = [regex]::Match($content, '(?ms)^##\s*Open[\s\S]*?(?=^##\s|\z)').Value
        $openTbds = ([regex]::Matches($openSection, '\[TBD-\d+\]') | ForEach-Object { $_.Value } | Sort-Object -Unique) -join ' '
        if ($openTbds) {
            Block "SDD: research.md ($($change.Name)) has unresolved decision points: $openTbds. Run `$spec-ask to resolve them first"
        }
    }

    exit 0
} catch {
    # A bug in the hook itself must not block the flow
    [Console]::Error.WriteLine("SDD check-tbd hook internal error (fail-open): $_")
    exit 0
}
