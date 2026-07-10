# Gate launcher: probe-and-fallback shim (the npm-shim / GitHub-Actions-runner pattern).
# WHY: hooks.json must not assume `pwsh` resolves from PATH -- PowerShell 7 is an optional
# install, and the Microsoft Store build exposes only a per-user 0-byte app-execution alias
# that process-level PATH searches (like the hook runner's) may fail to resolve, while
# powershell.exe 5.1 IS guaranteed on every Windows box. So 5.1 hosts this launcher, which:
#   1. probes for pwsh (PATH -> MSI default dir -> Store alias) and delegates when found
#      (stdin handle is inherited by the child untouched -- verified byte-intact for UTF-8);
#   2. otherwise runs the gate script in-process -- every gate script is PS 5.1-compatible
#      and sets its own UTF-8 console encoding before reading stdin.
# The blocking contract (exit 2 + stderr) passes through unchanged on both paths.
# fail-open: launcher internal errors exit 0 (a shim bug must never block the flow).

$ErrorActionPreference = 'Continue'

try {
    $gate = $args[0]
    if ([string]::IsNullOrWhiteSpace($gate) -or -not (Test-Path -LiteralPath $gate)) { exit 0 }

    # Decode child stderr/stdout as UTF-8 (5.1 defaults to the OEM codepage)
    [Console]::OutputEncoding = [System.Text.Encoding]::UTF8

    $pwshExe = $null
    $found = Get-Command pwsh -CommandType Application -ErrorAction SilentlyContinue
    if ($found) { $pwshExe = @($found)[0].Source }
    if (-not $pwshExe) {
        $candidates = @()
        if ($env:ProgramFiles)  { $candidates += (Join-Path $env:ProgramFiles 'PowerShell\7\pwsh.exe') }
        if ($env:LOCALAPPDATA)  { $candidates += (Join-Path $env:LOCALAPPDATA 'Microsoft\WindowsApps\pwsh.exe') }
        foreach ($c in $candidates) {
            if (Test-Path -LiteralPath $c) { $pwshExe = $c; break }
        }
    }

    if ($pwshExe) {
        # Delegate: the child inherits this process's stdin (never read here)
        & $pwshExe -NoProfile -NonInteractive -ExecutionPolicy Bypass -File $gate
        exit $LASTEXITCODE
    }

    # Fallback: run the gate in-process under 5.1 -- stdin is still unconsumed, the gate
    # reads it itself. A script-scope `exit N` does NOT end this process; it surfaces in
    # $LASTEXITCODE (which stays $null when the gate never exits -> `exit $null` = 0, fail-open)
    & $gate
    exit $LASTEXITCODE
} catch {
    [Console]::Error.WriteLine("SDD gate-launcher internal error (fail-open): $_")
    exit 0
}
