#!/usr/bin/env pwsh
# Stop-event reminder: implementation ended without a closing verification
# Trigger: Stop hook (fires when Claude ends its turn)
# Behavior: if the single active change has an APPROVED proposal but no verify.md
# ledger, exit 2 -- the stderr nudges Claude to run the closing three-dimension
# verification (or to state explicitly that it is pausing and why, then stop).
# This is a REMINDER, not a gate: stop_hook_active (set by the runtime when a stop
# hook already fired this cycle) guards against loops -- at most one nudge per stop.
# fail-open: internal errors exit 0.

[Console]::InputEncoding = [System.Text.Encoding]::UTF8
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$ErrorActionPreference = 'Continue'

try {
    $stdin = [Console]::In.ReadToEnd()
    if ([string]::IsNullOrWhiteSpace($stdin)) { exit 0 }

    $data = $stdin | ConvertFrom-Json

    # Loop guard: a stop hook already fired in this stop cycle -- let Claude stop
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
    # Same marker contract as check-gate.ps1: implementation window = APPROVED present
    if ($content -notmatch '(?i)<!--\s*APPROVED\s*[:>]') { exit 0 }

    $ledgerPath = Join-Path $change.FullName 'verify.md'
    if (Test-Path $ledgerPath) { exit 0 }

    [Console]::Error.WriteLine("SDD: change '$($change.Name)' has an approved proposal but no verification ledger (verify.md).")
    [Console]::Error.WriteLine('If implementation just finished: run the closing three-dimension verification now and write the ledger round (see /spec:verify -- findings with V-N IDs + Evidence).')
    [Console]::Error.WriteLine('If you are deliberately pausing (stuck self-check / awaiting a user decision / mid-implementation): say so explicitly to the user, then stop.')
    exit 2
} catch {
    [Console]::Error.WriteLine("SDD check-verify-reminder hook internal error (fail-open): $_")
    exit 0
}
