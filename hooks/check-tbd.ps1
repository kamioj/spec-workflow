#!/usr/bin/env pwsh
# /spec:propose 前置检查：research.md 的 ## Open [TBD] 必须清空
# 触发：UserPromptSubmit hook
# 行为：用户输入含 /spec:propose 时扫描 research.md；含 [TBD] 则 exit 2 阻断

# UTF-8 stdin/stdout
[Console]::InputEncoding = [System.Text.Encoding]::UTF8
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$ErrorActionPreference = 'Continue'

try {
    $stdin = [Console]::In.ReadToEnd()
    if ([string]::IsNullOrWhiteSpace($stdin)) { exit 0 }

    $data = $stdin | ConvertFrom-Json
    # UserPromptSubmit 的 stdin JSON 字段名是 user_prompt（不是 prompt）
    $userPrompt = $data.user_prompt
    $cwd = $data.cwd

    # 只在用户输入含 /spec:propose 时触发
    if ($userPrompt -notmatch '/spec:propose') { exit 0 }

    # 找未归档 change（spec/changes/<name>/，排除 archive）
    $changesDir = Join-Path $cwd 'spec' | Join-Path -ChildPath 'changes'
    if (-not (Test-Path $changesDir)) { exit 0 }

    $changes = Get-ChildItem $changesDir -Directory -ErrorAction SilentlyContinue |
               Where-Object { $_.Name -ne 'archive' }

    if (-not $changes -or $changes.Count -eq 0) {
        [Console]::Error.WriteLine('SDD: 没有活跃 change。先调 /spec:research <方向> 启动')
        exit 2
    }

    if ($changes.Count -gt 1) {
        $names = ($changes | ForEach-Object { $_.Name }) -join ', '
        [Console]::Error.WriteLine("SDD: 检测到多个活跃 change（$names）。本工作流假设单活跃 change——先 /spec:archive 其余、或清理后再 /spec:propose")
        exit 2
    }

    foreach ($change in $changes) {
        $researchPath = Join-Path $change.FullName 'research.md'
        if (-not (Test-Path $researchPath)) {
            [Console]::Error.WriteLine("SDD: $($change.Name) 缺 research.md。先调 /spec:research <方向>")
            exit 2
        }

        $content = Get-Content $researchPath -Raw -Encoding UTF8

        # 去掉 ## Decided 段（其中 "来源 [TBD-N]" 是已消化引用、不算未决），剩余全文扫未消化的 [TBD-N]
        # 兜底：即使 LLM 漏写 ## Open [TBD] 标题、或把 [TBD-N] 埋在别的段，也能拦住（硬约束不被静默绕过）
        $scanText = $content -replace '(?ms)^##\s*Decided[\s\S]*?(?=^##\s+|\z)', ''
        if ($scanText -match '\[TBD-\d+\]') {
            [Console]::Error.WriteLine("SDD: research.md ($($change.Name)) 含未消化的 [TBD] 决策点。先调 /spec:ask 消化")
            exit 2
        }
    }

    exit 0
} catch {
    # hook 自身 bug 不应阻断流程
    [Console]::Error.WriteLine("SDD check-tbd hook 内部错误（已放行）: $_")
    exit 0
}
