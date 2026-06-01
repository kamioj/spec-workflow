#!/usr/bin/env pwsh
# 契约指纹共享库 —— 被 hooks/check-source-gate.ps1 与 scripts/mint-fingerprint.ps1 dot-source。
# 契约包定义来自 config/workflow-model.json（单一真相源）；本库只做计算，不读模型路径。
# 指纹算法：规一化行尾(CRLF→LF) 后对每个存在的契约文件算 SHA256（per-file），
#           combined = SHA256(按文件名排序的 "name=hash" 行)。mint 与 gate 必须用同一套，勿擅改。

function Read-WorkflowModel {
    param([Parameter(Mandatory)][string]$PluginRoot)
    $modelPath = Join-Path $PluginRoot 'config' | Join-Path -ChildPath 'workflow-model.json'
    if (-not (Test-Path $modelPath)) { return $null }
    try { return Get-Content $modelPath -Raw -Encoding UTF8 | ConvertFrom-Json } catch { return $null }
}

function Get-NormalizedFileHash {
    param([Parameter(Mandatory)][string]$Path)
    $text = [System.IO.File]::ReadAllText($Path)
    $text = $text -replace "`r`n", "`n"
    # 剔除 APPROVED / VERIFIED 标记行：它们由 mint/verify 写进 proposal，属于"批准/校验动作"而非契约内容，
    # 不能计入指纹——否则 mint 写完标记会立刻让自己刚算的指纹漂移。
    $text = [regex]::Replace($text, '(?m)^[ \t]*<!--[ \t]*(APPROVED|VERIFIED):.*?-->[ \t]*\n?', '')
    $text = $text.TrimEnd() + "`n"
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($text)
    $sha = [System.Security.Cryptography.SHA256]::Create()
    try { $h = $sha.ComputeHash($bytes) } finally { $sha.Dispose() }
    return ([System.BitConverter]::ToString($h) -replace '-', '').ToLowerInvariant()
}

function Get-ContractFingerprint {
    # 返回 @{ subject = @(@{name;sha256}...); combined = "sha256:<hex>" }
    param([Parameter(Mandatory)][string]$ChangeDir, [Parameter(Mandatory)][array]$Bundle)
    $subject = @()
    foreach ($name in $Bundle) {
        $p = Join-Path $ChangeDir $name
        if (Test-Path $p -PathType Leaf) {
            $subject += [ordered]@{ name = $name; sha256 = (Get-NormalizedFileHash -Path $p) }
        }
    }
    $subject = @($subject)
    $lines = (@($subject | Sort-Object { $_.name } | ForEach-Object { "$($_.name)=$($_.sha256)" })) -join "`n"
    $cb = [System.Text.Encoding]::UTF8.GetBytes($lines)
    $sha = [System.Security.Cryptography.SHA256]::Create()
    try { $ch = $sha.ComputeHash($cb) } finally { $sha.Dispose() }
    $combined = ([System.BitConverter]::ToString($ch) -replace '-', '').ToLowerInvariant()
    return [ordered]@{ subject = $subject; combined = "sha256:$combined" }
}

function Write-ContractFingerprint {
    param([Parameter(Mandatory)][string]$ChangeDir, [Parameter(Mandatory)][array]$Bundle)
    $fp = Get-ContractFingerprint -ChangeDir $ChangeDir -Bundle $Bundle
    $record = [ordered]@{
        subject  = @($fp.subject)
        combined = $fp.combined
        mintedAt = (Get-Date).ToString('yyyy-MM-dd HH:mm')
    }
    $out = Join-Path $ChangeDir '.fingerprint.json'
    $record | ConvertTo-Json -Depth 6 | Set-Content -Path $out -Encoding UTF8
    return $fp.combined
}

function Test-ContractFingerprint {
    # 返回 @{ status = 'match'|'drift'|'missing'; drifted = @(names) }
    param([Parameter(Mandatory)][string]$ChangeDir, [Parameter(Mandatory)][array]$Bundle)
    $fpFile = Join-Path $ChangeDir '.fingerprint.json'
    if (-not (Test-Path $fpFile)) { return [ordered]@{ status = 'missing'; drifted = @() } }
    try { $saved = Get-Content $fpFile -Raw -Encoding UTF8 | ConvertFrom-Json } catch { return [ordered]@{ status = 'missing'; drifted = @() } }
    $now = Get-ContractFingerprint -ChangeDir $ChangeDir -Bundle $Bundle
    if ($now.combined -eq $saved.combined) { return [ordered]@{ status = 'match'; drifted = @() } }
    $savedMap = @{}; foreach ($s in $saved.subject) { $savedMap[$s.name] = $s.sha256 }
    $nowMap = @{};   foreach ($s in $now.subject)   { $nowMap[$s.name]   = $s.sha256 }
    $names = @(@($savedMap.Keys) + @($nowMap.Keys) | Select-Object -Unique)
    $drifted = @()
    foreach ($n in $names) { if ($savedMap[$n] -ne $nowMap[$n]) { $drifted += $n } }
    return [ordered]@{ status = 'drift'; drifted = @($drifted) }
}
