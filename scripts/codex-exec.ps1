#!/usr/bin/env pwsh
<#
.SYNOPSIS
  Unified wrapper for invoking the codex CLI — shared by /spec:propose --codex and /spec:verify --codex.

.DESCRIPTION
  Keeps the entire invocation mechanism for codex's heterogeneous review in one place (single source of truth);
  command files just call this script instead of inlining their own copies.

  Measured constraints (violating them hangs / silently fails on Windows, verified):
    --dangerously-bypass-approvals-and-sandbox   works around #336: the Windows sandbox hangs (-s read-only measured hanging for 11 minutes)
    direct command-line call, not via node spawn (this script uses & codex)  works around #337: spawn('codex') throws ENOENT
    -c model_reasoning_effort=low                cost control: one xhigh run burns ~22k tokens
    Start-Job + timeout + leftover-process cleanup   anti-hang: a bare run was measured hanging for 11 minutes

.PARAMETER Prompt
  The review prompt (required). For the --fix case, pass a "review and fix" instruction; bypassing the sandbox lets codex write files.

.PARAMETER TimeoutSec
  Timeout in seconds, default 300. propose's solution critique typically uses 180, verify's code review typically uses 300.

.PARAMETER ProjectDir
  codex working directory (passed as -C). verify's code review passes the project root; propose's plain-text critique can omit it.

.PARAMETER ResumeSession
  The session id to resume. If propose --codex left a .codex-session, pass it so codex remembers the solution it reviewed.

.OUTPUTS
  codex's body (findings) is emitted line by line, with the last line being a structured status:
    OK:session=<id>     success (<id> is empty when the session can't be parsed)
    ERR:timeout:<n>s    timeout
    ERR:<message>       other failure
  fail-open is the caller's decision — this script only returns the status faithfully, it doesn't block the flow.

.EXAMPLE
  pwsh -File codex-exec.ps1 -Prompt "Review this diff" -TimeoutSec 300 -ProjectDir "D:\proj"

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

# Assemble the codex arguments (direct command-line call + splat, not via node spawn — works around #337)
$codexArgs = @('exec')
if ($ResumeSession) { $codexArgs += @('resume', $ResumeSession) }
$codexArgs += @('--dangerously-bypass-approvals-and-sandbox', '-c', 'model_reasoning_effort=low')  # works around #336 + cost control
if ($ProjectDir)    { $codexArgs += @('-C', $ProjectDir) }
$codexArgs += $Prompt

$t0  = Get-Date
$job = Start-Job -ScriptBlock { param($a) & codex @a 2>&1 } -ArgumentList (, $codexArgs)

try {
    if (Wait-Job $job -Timeout $TimeoutSec) {
        $out = Receive-Job $job
        $out                                   # emit codex's body (findings) as-is

        # Parse the session id (codex output looks like "session id: <id>")
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
    # Clean up leftover codex processes (a bare run was measured hanging)
    Get-Process codex -ErrorAction SilentlyContinue |
        Where-Object { $_.StartTime -gt $t0 } |
        Stop-Process -Force -ErrorAction SilentlyContinue
}
