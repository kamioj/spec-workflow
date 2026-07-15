#!/usr/bin/env pwsh
# Codex port of the Stop-event reminder: implementation ended without a closing verification.
# Trigger: Stop hook (fires when the Codex agent ends its turn).
# Codex-specific contract (see SCHEMA.md, probe-verified on codex-cli 0.142.1):
#   - blocking = stdout {"decision":"block","reason":...} + exit 0 (exit 2 does NOT block on Codex)
#   - Stop payload carries stop_hook_active (loop guard, same semantics as Claude Code)
#   - NOTE: block-on-Stop is assumed symmetrical with UserPromptSubmit but was not yet
#     observed live -- the smoke test must confirm it (SCHEMA.md "Blocking semantics").
# Behavior: if the single active change has an APPROVED proposal but no verify.md
# ledger, block once -- the reason nudges the agent to run the closing verification
# (or to state explicitly that it is pausing and why, then stop).
# This is a REMINDER, not a gate: stop_hook_active guards against loops (one nudge per stop).
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

    # Loop guard: a stop hook already fired in this stop cycle -- let the agent stop
    if ($data.stop_hook_active) { exit 0 }

    $cwd = $data.cwd
    if ([string]::IsNullOrWhiteSpace($cwd)) { exit 0 }

    $changesDir = Join-Path $cwd 'spec' | Join-Path -ChildPath 'changes'
    if (-not (Test-Path $changesDir)) { exit 0 }

    $changes = Get-ChildItem $changesDir -Directory -ErrorAction SilentlyContinue |
               Where-Object { $_.Name -ne 'archive' }

    # Only nudge in the unambiguous single-active-change window
    if (-not $changes -or $changes.Count -ne 1) { exit 0 }

    $change = $changes[0]

    $proposalPath = Join-Path $change.FullName 'proposal.md'
    if (-not (Test-Path $proposalPath)) { exit 0 }

    $content = Get-Content $proposalPath -Raw -Encoding UTF8
    # Same marker contract as check-gate: implementation window = APPROVED present
    if ($content -notmatch '(?i)<!--\s*APPROVED\s*[:>]') { exit 0 }

    # A ledger only counts once it has an implementation round (round >= 1). Round 0 is the
    # propose-stage critique panel (written BEFORE any code exists) -- treating it as
    # "verified" would disarm this reminder for the whole implementation window, letting
    # premature turn-endings mid-apply pass silently.
    $ledgerPath = Join-Path $change.FullName 'verify.md'
    if (Test-Path $ledgerPath) {
        $ledger = Get-Content $ledgerPath -Raw -Encoding UTF8
        if ($ledger -match '(?m)^round:\s*[1-9]') { exit 0 }
    }

    $lines = @(
        "SDD: change '$($change.Name)' has an approved proposal but no implementation-round verification (verify.md absent, or holds only the round-0 critique).",
        'If implementation is unfinished (unchecked tasks.md items / What items not landed): CONTINUE implementing -- do not end the turn.',
        'If implementation just finished: run the closing three-dimension verification now and write the ledger round (see $spec-verify -- findings with V-N IDs + Evidence).',
        'If you are deliberately pausing (stuck self-check / awaiting a user decision): say so explicitly to the user, then stop.'
    )
    Block ($lines -join "`n")
} catch {
    [Console]::Error.WriteLine("SDD check-verify-reminder hook internal error (fail-open): $_")
    exit 0
}
