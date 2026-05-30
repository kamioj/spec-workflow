#!/usr/bin/env pwsh
# /sdd:apply 前置检查：proposal.md 必须存在
# 触发：UserPromptSubmit hook
# 行为：用户输入含 /sdd:apply 时扫描 proposal.md；缺 proposal 则 exit 2 阻断

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

    if ($userPrompt -notmatch '/sdd:apply') { exit 0 }

    $changesDir = Join-Path $cwd 'spec' | Join-Path -ChildPath 'changes'
    if (-not (Test-Path $changesDir)) {
        [Console]::Error.WriteLine('SDD: 没有 spec/changes/ 目录。先走 /sdd:research → /sdd:propose')
        exit 2
    }

    $changes = Get-ChildItem $changesDir -Directory -ErrorAction SilentlyContinue |
               Where-Object { $_.Name -ne 'archive' }

    if (-not $changes -or $changes.Count -eq 0) {
        [Console]::Error.WriteLine('SDD: 没有活跃 change。先走 /sdd:research → /sdd:propose')
        exit 2
    }

    foreach ($change in $changes) {
        $proposalPath = Join-Path $change.FullName 'proposal.md'
        if (-not (Test-Path $proposalPath)) {
            [Console]::Error.WriteLine("SDD: $($change.Name) 缺 proposal.md。先调 /sdd:propose")
            exit 2
        }

    }

    exit 0
} catch {
    [Console]::Error.WriteLine("SDD check-gate hook 内部错误（已放行）: $_")
    exit 0
}
