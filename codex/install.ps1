#!/usr/bin/env pwsh
# SDD-for-Codex installer (Windows / pwsh).
# Copies: skills -> ~/.agents/skills/, agents -> ~/.codex/agents/, hooks -> ~/.codex/sdd-hooks/,
# and generates ~/.codex/hooks.json from hooks/hooks.json.template.
# Refuses to overwrite an existing ~/.codex/hooks.json (merge by hand instead) -- a silent
# clobber of someone's hook config is worse than a failed install.
# After installing, Codex must still TRUST the hooks once: open the codex TUI and approve
# them in the hooks browser (untrusted hooks are silently skipped -- see hooks/SCHEMA.md).

$ErrorActionPreference = 'Stop'

$src = $PSScriptRoot
$skillsDst = Join-Path $HOME '.agents/skills'
$agentsDst = Join-Path $HOME '.codex/agents'
$hooksDst  = Join-Path $HOME '.codex/sdd-hooks'
$hooksJson = Join-Path $HOME '.codex/hooks.json'

# 1. Skills
New-Item -ItemType Directory -Force $skillsDst | Out-Null
Get-ChildItem (Join-Path $src 'skills') -Directory | ForEach-Object {
    Copy-Item $_.FullName $skillsDst -Recurse -Force
    Write-Host "skill:  $($_.Name) -> $skillsDst"
}

# 2. Agents
New-Item -ItemType Directory -Force $agentsDst | Out-Null
Get-ChildItem (Join-Path $src 'agents') -Filter '*.toml' | ForEach-Object {
    Copy-Item $_.FullName $agentsDst -Force
    Write-Host "agent:  $($_.Name) -> $agentsDst"
}

# 3. Hook scripts
New-Item -ItemType Directory -Force $hooksDst | Out-Null
Get-ChildItem (Join-Path $src 'hooks') -File | Where-Object { $_.Extension -in '.ps1', '.sh' } | ForEach-Object {
    Copy-Item $_.FullName $hooksDst -Force
}
Write-Host "hooks:  8 gate scripts -> $hooksDst"

# 4. hooks.json (generated with the absolute install path; forward slashes work everywhere)
if (Test-Path $hooksJson) {
    Write-Error ("$hooksJson already exists. Refusing to overwrite -- merge the entries from " +
        (Join-Path $src 'hooks/hooks.json.template') +
        " by hand (replace __SDD_HOOKS_DIR__ with $($hooksDst -replace '\\','/'))")
}
$dirForJson = $hooksDst -replace '\\', '/'
(Get-Content (Join-Path $src 'hooks/hooks.json.template') -Raw -Encoding UTF8) -replace '__SDD_HOOKS_DIR__', $dirForJson |
    Set-Content $hooksJson -Encoding UTF8 -NoNewline
Write-Host "config: $hooksJson generated"

Write-Host ''
Write-Host 'Done. One manual step remains: hooks will NOT run until trusted.'
Write-Host 'Open the codex TUI once and approve the SDD hooks in the hooks browser,'
Write-Host 'then verify the gate actually bites: in a project without spec/changes/,'
Write-Host 'send "$spec-apply" -- it must be blocked with an SDD message.'
