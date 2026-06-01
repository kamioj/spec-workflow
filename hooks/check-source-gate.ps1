#!/usr/bin/env pwsh
# PreToolUse 门（Write|Edit|MultiEdit）—— 决策→实施 的动作级边界。
# 写 spec/ 外的源码时：当前活跃 change 必须已 APPROVED 且契约指纹未漂移，否则 exit 2 阻断。
# 不看命令名、只看动作 → 手动模式和一把梭模式一视同仁。fail-open。
[Console]::InputEncoding = [System.Text.Encoding]::UTF8
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$ErrorActionPreference = 'Continue'

try {
    $stdin = [Console]::In.ReadToEnd()
    if ([string]::IsNullOrWhiteSpace($stdin)) { exit 0 }
    $data = $stdin | ConvertFrom-Json
    $cwd = $data.cwd
    $filePath = $data.tool_input.file_path
    if ([string]::IsNullOrWhiteSpace($cwd) -or [string]::IsNullOrWhiteSpace($filePath)) { exit 0 }

    # 1. 路径分类：spec/ 内 = 契约/决策产物，放行
    if (-not [System.IO.Path]::IsPathRooted($filePath)) { $filePath = Join-Path $cwd $filePath }
    $full = [System.IO.Path]::GetFullPath($filePath)
    $specRoot = [System.IO.Path]::GetFullPath((Join-Path $cwd 'spec'))
    $sep = [System.IO.Path]::DirectorySeparatorChar
    if ($full -eq $specRoot -or $full.StartsWith($specRoot + $sep, [System.StringComparison]::OrdinalIgnoreCase)) { exit 0 }

    # 2. 找活跃 change（非 archive、有 proposal.md）
    $changesDir = Join-Path $cwd 'spec' | Join-Path -ChildPath 'changes'
    if (-not (Test-Path $changesDir)) { exit 0 }
    $active = @(Get-ChildItem $changesDir -Directory -ErrorAction SilentlyContinue |
                Where-Object { $_.Name -ne 'archive' -and (Test-Path (Join-Path $_.FullName 'proposal.md')) })
    if ($active.Count -eq 0) { exit 0 }
    if ($active.Count -gt 1) {
        [Console]::Error.WriteLine('SDD 门：检测到多个活跃 change，v1 暂不处理多 change，已放行（建议先 /spec:archive 收敛到单个）')
        exit 0
    }
    $change = $active[0].FullName
    $changeName = $active[0].Name
    $target = [System.IO.Path]::GetFileName($full)

    # 3. APPROVED 检查
    $proposal = Join-Path $change 'proposal.md'
    $pc = Get-Content $proposal -Raw -Encoding UTF8
    if ($pc -notmatch '(?i)<!--\s*APPROVED:') {
        [Console]::Error.WriteLine("SDD 门拦截：契约「$changeName」未批准，不能写源码 [$target]。先过 /spec:apply（它会铸契约指纹并批准）再实施。")
        exit 2
    }

    # 4. 指纹校验（防批准后漂移）
    $pluginRoot = if ($env:CLAUDE_PLUGIN_ROOT) { $env:CLAUDE_PLUGIN_ROOT } else { Split-Path $PSScriptRoot -Parent }
    $libPath = Join-Path $pluginRoot 'scripts' | Join-Path -ChildPath 'contract-lib.ps1'
    if (-not (Test-Path $libPath)) { exit 0 }
    . $libPath
    $model = Read-WorkflowModel -PluginRoot $pluginRoot
    if (-not $model -or -not $model.contract.bundle) { exit 0 }
    $r = Test-ContractFingerprint -ChangeDir $change -Bundle $model.contract.bundle
    if ($r.status -eq 'missing') {
        [Console]::Error.WriteLine("SDD 门拦截：契约「$changeName」已批准但缺指纹（.fingerprint.json）。重跑 /spec:apply 重铸后再实施。")
        exit 2
    }
    if ($r.status -eq 'drift') {
        $files = ($r.drifted -join ', ')
        [Console]::Error.WriteLine("SDD 门拦截：契约「$changeName」自批准后漂移（$files 变了）。要么这是需求变更——回决策域改完重跑 /spec:apply 重铸指纹；要么把契约改回批准时的样子。漂移契约下不许写代码 [$target]。")
        exit 2
    }
    exit 0
} catch {
    [Console]::Error.WriteLine("SDD check-source-gate hook 内部错误（已放行）: $_")
    exit 0
}
