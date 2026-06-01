#!/usr/bin/env pwsh
<#
.SYNOPSIS
  统一封装 codex CLI 调用 —— 供 /spec:propose --codex 和 /spec:verify --codex 复用。

.DESCRIPTION
  把 codex 异构审查的全部调用机制收在一处（单一真相源），命令文件只调本脚本，不再各自内联。

  实测约束（违反则在 Windows 卡死 / 静默失败，已验证）：
    --dangerously-bypass-approvals-and-sandbox   绕 #336：Windows 沙盒挂起（-s read-only 实测卡死 11 分钟）
    命令行直调、不走 node spawn（本脚本用 & codex）  绕 #337：spawn('codex') 报 ENOENT
    -c model_reasoning_effort=low                控成本：xhigh 一次烧 ~2.2 万 token
    Start-Job + 超时 + 残留进程清理              防卡死：实测裸跑会卡 11 分钟

.PARAMETER Prompt
  审查提示（必填）。--fix 场景传"审查并修复"指令即可，bypass sandbox 允许 codex 写文件。

.PARAMETER TimeoutSec
  超时秒数，默认 300。propose 挑刺方案惯用 180，verify 审代码惯用 300。

.PARAMETER ProjectDir
  codex 工作目录（传 -C）。verify 审代码传项目根；propose 纯文本挑刺可省略。

.PARAMETER ResumeSession
  续会话 id。verify 若 propose --codex 留过 .codex-session，传入让 codex 记得它审过的方案。

.OUTPUTS
  codex 正文（findings）逐行输出，最后一行为结构化状态：
    OK:session=<id>     成功（解析不到 session 时 <id> 为空）
    ERR:timeout:<n>s    超时
    ERR:<message>       其他失败
  fail-open 由调用方决定 —— 本脚本只如实返回状态，不阻断流程。

.EXAMPLE
  pwsh -File codex-exec.ps1 -Prompt "审一下这段改动" -TimeoutSec 300 -ProjectDir "D:\proj"

.EXAMPLE
  pwsh -File codex-exec.ps1 -Prompt $p -ResumeSession 0f3a... -ProjectDir "D:\proj"
#>

param(
    [Parameter(Mandatory = $true)][string]$Prompt,
    [int]$TimeoutSec = 300,
    [string]$ProjectDir = '',
    [string]$ResumeSession = ''
)

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$ErrorActionPreference = 'Continue'

# 组装 codex 参数（命令行直调 + splat，不走 node spawn —— 绕 #337）
$codexArgs = @('exec')
if ($ResumeSession) { $codexArgs += @('resume', $ResumeSession) }
$codexArgs += @('--dangerously-bypass-approvals-and-sandbox', '-c', 'model_reasoning_effort=low')  # 绕 #336 + 控成本
if ($ProjectDir)    { $codexArgs += @('-C', $ProjectDir) }
$codexArgs += $Prompt

$t0  = Get-Date
$job = Start-Job -ScriptBlock { param($a) & codex @a 2>&1 } -ArgumentList (, $codexArgs)

try {
    if (Wait-Job $job -Timeout $TimeoutSec) {
        $out = Receive-Job $job
        $out                                   # 原样输出 codex 正文（findings）

        # 解析 session id（codex 输出形如 "session id: <id>"）
        $sid = ''
        $hit = $out | Select-String -Pattern 'session id:\s*(\S+)' | Select-Object -First 1
        if ($hit) { $sid = $hit.Matches[0].Groups[1].Value }
        "OK:session=$sid"
    }
    else {
        Stop-Job $job
        "ERR:timeout:${TimeoutSec}s"
    }
}
catch {
    "ERR:$($_.Exception.Message)"
}
finally {
    Remove-Job $job -Force -ErrorAction SilentlyContinue
    # 清理残留 codex 进程（实测裸跑会卡）
    Get-Process codex -ErrorAction SilentlyContinue |
        Where-Object { $_.StartTime -gt $t0 } |
        Stop-Process -Force -ErrorAction SilentlyContinue
}
