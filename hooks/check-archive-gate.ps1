#!/usr/bin/env pwsh
# UserPromptSubmit 门：/spec:archive 前，活跃 change 必须已 VERIFIED 且 verdict:pass，
# 且裁决时的契约指纹 == 当前契约指纹（防"验证后又改契约再归档"）。否则 exit 2。
# 校验→归档 的边界。归档是用户显式终结动作、不会被一把梭打包，故用 UserPromptSubmit 足够。fail-open。
[Console]::InputEncoding = [System.Text.Encoding]::UTF8
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$ErrorActionPreference = 'Continue'

try {
    $stdin = [Console]::In.ReadToEnd()
    if ([string]::IsNullOrWhiteSpace($stdin)) { exit 0 }
    $data = $stdin | ConvertFrom-Json
    $userPrompt = $data.user_prompt
    $cwd = $data.cwd
    if ([string]::IsNullOrWhiteSpace($cwd)) { exit 0 }
    if ($userPrompt -notmatch '/spec:archive') { exit 0 }
    if ($userPrompt -match '--abandon') { exit 0 }   # 废弃归档：失败/放弃的提案，不要求 VERIFIED

    $changesDir = Join-Path $cwd 'spec' | Join-Path -ChildPath 'changes'
    if (-not (Test-Path $changesDir)) { exit 0 }
    $active = @(Get-ChildItem $changesDir -Directory -ErrorAction SilentlyContinue |
                Where-Object { $_.Name -ne 'archive' -and (Test-Path (Join-Path $_.FullName 'proposal.md')) })
    if ($active.Count -eq 0) { exit 0 }
    if ($active.Count -gt 1) {
        [Console]::Error.WriteLine('SDD 归档门：多个活跃 change，v1/v2 暂不处理多 change，已放行（命令自行判断归档哪个）')
        exit 0
    }
    $change = $active[0].FullName
    $changeName = $active[0].Name
    $proposal = Join-Path $change 'proposal.md'
    $pc = Get-Content $proposal -Raw -Encoding UTF8

    # 1. 必须有 VERIFIED ... verdict:pass
    if ($pc -notmatch '(?i)<!--\s*VERIFIED:[^>]*verdict:\s*pass') {
        [Console]::Error.WriteLine("SDD 归档门拦截：契约「$changeName」未验证通过，不能归档。先 /spec:verify 跑到 pass（生成 verdict.md + VERIFIED 标记）。")
        exit 2
    }

    # 2. 裁决时的 fp == 当前契约 fp（防验证后又改契约）
    $m = [regex]::Match($pc, '(?i)<!--\s*VERIFIED:[^>]*fp:(sha256:[0-9a-f]+)[^>]*verdict:\s*pass')
    $verifiedFp = if ($m.Success) { $m.Groups[1].Value.ToLowerInvariant() } else { $null }
    if ($verifiedFp) {
        $pluginRoot = if ($env:CLAUDE_PLUGIN_ROOT) { $env:CLAUDE_PLUGIN_ROOT } else { Split-Path $PSScriptRoot -Parent }
        $libPath = Join-Path $pluginRoot 'scripts' | Join-Path -ChildPath 'contract-lib.ps1'
        if (Test-Path $libPath) {
            . $libPath
            $model = Read-WorkflowModel -PluginRoot $pluginRoot
            if ($model -and $model.contract.bundle) {
                $cur = (Get-ContractFingerprint -ChangeDir $change -Bundle $model.contract.bundle).combined
                if ($cur -ne $verifiedFp) {
                    [Console]::Error.WriteLine("SDD 归档门拦截：契约「$changeName」验证后又改了（验证时 $verifiedFp，现在 $cur）。重跑 /spec:verify 再归档。")
                    exit 2
                }
            }
        }
    }

    exit 0
} catch {
    [Console]::Error.WriteLine("SDD check-archive-gate hook 内部错误（已放行）: $_")
    exit 0
}
