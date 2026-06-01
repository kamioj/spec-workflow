#!/usr/bin/env pwsh
# approval 铸契约指纹（决策→实施 交界）：
#   1. 算契约包各文件 sha256 → 写 <change>/.fingerprint.json
#   2. 在 proposal.md 末尾写/刷新 APPROVED 标记（带 combined fp）
# 用法：pwsh -File mint-fingerprint.ps1 -ChangeDir <spec/changes/xxx>
param([Parameter(Mandatory)][string]$ChangeDir)

$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$pluginRoot = if ($env:CLAUDE_PLUGIN_ROOT) { $env:CLAUDE_PLUGIN_ROOT } else { Split-Path $PSScriptRoot -Parent }
. (Join-Path $pluginRoot 'scripts' | Join-Path -ChildPath 'contract-lib.ps1')

$model = Read-WorkflowModel -PluginRoot $pluginRoot
if (-not $model -or -not $model.contract.bundle) { Write-Error 'workflow-model.json 缺失或无 contract.bundle'; exit 1 }
if (-not (Test-Path $ChangeDir)) { Write-Error "change 目录不存在: $ChangeDir"; exit 1 }

$combined = Write-ContractFingerprint -ChangeDir $ChangeDir -Bundle $model.contract.bundle

$proposal = Join-Path $ChangeDir 'proposal.md'
if (Test-Path $proposal) {
    $content = Get-Content $proposal -Raw -Encoding UTF8
    # 去掉旧 APPROVED 标记（连同其行），再追加新的
    $content = [regex]::Replace($content, '(?m)^[ \t]*<!--[ \t]*APPROVED:.*?-->[ \t]*\r?\n?', '')
    $stamp = (Get-Date).ToString('yyyy-MM-dd HH:mm')
    $marker = "<!-- APPROVED: $stamp fp:$combined -->"
    $content = $content.TrimEnd() + "`n`n" + $marker + "`n"
    Set-Content -Path $proposal -Value $content -Encoding UTF8
}

Write-Output "OK fp=$combined"
