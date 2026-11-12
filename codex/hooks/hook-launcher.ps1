# Codex hook launcher (Windows): probe-and-fallback shim between hooks.json and the pwsh twins.
# WHY: commandWindows must not name bare `pwsh` -- PowerShell 7 is an optional install, and the
# Microsoft Store build lives in %LOCALAPPDATA%\Microsoft\WindowsApps, a folder a user PATH can
# lack. Codex spawns commandWindows directly (no shell), so an unresolvable `pwsh` makes every
# hook report "Failed" and Codex fails open -- the gates go silently dead. powershell.exe 5.1 IS
# guaranteed on every Windows box, so it hosts this launcher, which:
#   1. probes for pwsh (PATH -> MSI default dir -> Store alias) and delegates when found; the
#      child inherits this process's stdin untouched (never read here);
#   2. otherwise runs the hook in-process under 5.1 -- every Codex .ps1 twin stays
#      5.1-compatible and pure ASCII, and sets its own UTF-8 console encoding before reading stdin.
# The Codex contract (stdout JSON + exit 0) passes through unchanged on both paths.
# `hook-launcher.ps1 --probe` prints the path a real run would take (the fixture runner reports
# it, so a run that meant to cover the 5.1 path can see that it did).
# fail-open: launcher internal errors exit 0 with no stdout (a shim bug must never block).

$ErrorActionPreference = 'Continue'

try {
    $hook = $args[0]

    $pwshExe = $null
    $found = Get-Command pwsh -CommandType Application -ErrorAction SilentlyContinue
    if ($found) { $pwshExe = @($found)[0].Source }
    if (-not $pwshExe) {
        $candidates = @()
        if ($env:ProgramFiles) { $candidates += (Join-Path $env:ProgramFiles 'PowerShell\7\pwsh.exe') }
        if ($env:LOCALAPPDATA) { $candidates += (Join-Path $env:LOCALAPPDATA 'Microsoft\WindowsApps\pwsh.exe') }
        foreach ($c in $candidates) {
            if (Test-Path -LiteralPath $c) { $pwshExe = $c; break }
        }
    }

    if ($hook -eq '--probe') {
        if ($pwshExe) { [Console]::Out.WriteLine("delegate: $pwshExe") } else { [Console]::Out.WriteLine('in-process: Windows PowerShell 5.1') }
        exit 0
    }
    if ([string]::IsNullOrWhiteSpace($hook) -or -not (Test-Path -LiteralPath $hook)) { exit 0 }

    # Decode the child's stdout as UTF-8 and re-emit it as UTF-8 (5.1 defaults to the OEM codepage)
    [Console]::OutputEncoding = [System.Text.Encoding]::UTF8

    if ($pwshExe) {
        & $pwshExe -NoProfile -NonInteractive -ExecutionPolicy Bypass -File $hook
        exit $LASTEXITCODE
    }

    # Fallback: run the hook in-process under 5.1. A script-scope `exit N` does NOT end this
    # process; it surfaces in $LASTEXITCODE ($null when the hook never exits -> exit 0).
    & $hook
    exit $LASTEXITCODE
} catch {
    [Console]::Error.WriteLine("SDD hook-launcher internal error (fail-open): $_")
    exit 0
}
