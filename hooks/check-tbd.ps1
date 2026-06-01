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

    foreach ($change in $changes) {
        $researchPath = Join-Path $change.FullName 'research.md'
        if (-not (Test-Path $researchPath)) {
            [Console]::Error.WriteLine("SDD: $($change.Name) 缺 research.md。先调 /spec:research <方向>")
            exit 2
        }

        $content = Get-Content $researchPath -Raw -Encoding UTF8

        # 提取 ## Open [TBD] 段（直到下一个 ## 或文件结尾）
        if ($content -match '(?ms)^##\s*Open\s*\[TBD\][\s\S]*?(?=^##\s+|\z)') {
            $openSection = $matches[0]
            if ($openSection -match '\[TBD-\d+\]') {
                [Console]::Error.WriteLine("SDD: research.md ($($change.Name)) 含未消化的 [TBD] 决策点。先调 /spec:ask 消化")
                exit 2
            }
        }
    }

    exit 0
} catch {
    # hook 自身 bug 不应阻断流程
    [Console]::Error.WriteLine("SDD check-tbd hook 内部错误（已放行）: $_")
    exit 0
}
