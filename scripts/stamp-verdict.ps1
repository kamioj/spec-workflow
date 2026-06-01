#!/usr/bin/env pwsh
# 校验域裁决：在 proposal.md 末尾写/刷新 VERIFIED 标记（带当前契约 combined fp + verdict）。
# verdict.md 的逐点明细由 /spec:verify 命令撰写；本脚本只负责确定性地盖"裁决锚点"标记。
# VERIFIED 标记被指纹计算排除（见 contract-lib），盖标记不会造成漂移。
# 用法：pwsh -File stamp-verdict.ps1 -ChangeDir <spec/changes/xxx> -Verdict <pass|fail>
param(
    [Parameter(Mandatory)][string]$ChangeDir,
    [Parameter(Mandatory)][ValidateSet('pass', 'fail')][string]$Verdict
)

$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$pluginRoot = if ($env:CLAUDE_PLUGIN_ROOT) { $env:CLAUDE_PLUGIN_ROOT } else { Split-Path $PSScriptRoot -Parent }
. (Join-Path $pluginRoot 'scripts' | Join-Path -ChildPath 'contract-lib.ps1')

$model = Read-WorkflowModel -PluginRoot $pluginRoot
if (-not $model -or -not $model.contract.bundle) { Write-Error 'workflow-model.json 缺失或无 contract.bundle'; exit 1 }
if (-not (Test-Path $ChangeDir)) { Write-Error "change 目录不存在: $ChangeDir"; exit 1 }

$fp = (Get-ContractFingerprint -ChangeDir $ChangeDir -Bundle $model.contract.bundle).combined

$proposal = Join-Path $ChangeDir 'proposal.md'
if (Test-Path $proposal) {
    $content = Get-Content $proposal -Raw -Encoding UTF8
    $content = [regex]::Replace($content, '(?m)^[ \t]*<!--[ \t]*VERIFIED:.*?-->[ \t]*\r?\n?', '')
    $stamp = (Get-Date).ToString('yyyy-MM-dd HH:mm')
    $marker = "<!-- VERIFIED: $stamp fp:$fp verdict:$Verdict -->"
    $content = $content.TrimEnd() + "`n`n" + $marker + "`n"
    Set-Content -Path $proposal -Value $content -Encoding UTF8
}

Write-Output "OK verdict=$Verdict fp=$fp"
