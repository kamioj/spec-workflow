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
        Block 'SDD: no spec/changes/ directory. Start with $spec-research -> $spec-propose
(note: hooks resolve spec/ at the session cwd -- a spec/ tree anywhere else (a subdirectory, another worktree, the main repo) is invisible to every gate: move it to this root, or relaunch the session where that tree lives)'
    }

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
        Block "SDD: no active change under $changesDir (.paused / quick / fix / loop dirs do not count). Start with `$spec-research -> `$spec-propose. Already have one? It may sit in a DIFFERENT spec tree (another worktree / the main repo / a subproject) -- hooks only see the session cwd: move it here, or relaunch there"
    }

    if ($changes.Count -gt 1) {
        $names = ($changes | ForEach-Object { $_.Name }) -join ', '
        Block "SDD: multiple active changes detected under $changesDir ($names). This workflow assumes a single active change -- `$spec-archive the rest (or clean them up) before `$spec-apply (otherwise a draft change blocks the approved one)"
    }

    foreach ($change in $changes) {
        $proposalPath = Join-Path $change.FullName 'proposal.md'
        if (-not (Test-Path $proposalPath)) {
            # Self-diagnosis: name what the gate actually saw, so a change created in a
            # different spec tree (worktree / main repo / subproject) is recognizable (0.6.4).
            $found = (Get-ChildItem $change.FullName -Force -Name -ErrorAction SilentlyContinue) -join ' '
            if ([string]::IsNullOrWhiteSpace($found)) { $found = '(empty)' }
            Block ("SDD: change '$($change.Name)' is missing proposal.md -- run `$spec-propose first.`n" +
                   "(gate inspected $changesDir; '$($change.Name)' holds: $found. Not the change you meant? Yours likely sits in a DIFFERENT spec tree -- another worktree / the main repo / a subproject: hooks only see the session cwd; move it here, or relaunch the session where it lives)")
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
