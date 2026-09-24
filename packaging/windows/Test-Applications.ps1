#requires -Version 7.0
param([Parameter(Mandatory)][string]$PackageDirectory)
$ErrorActionPreference = 'Stop'
$package = (Resolve-Path -LiteralPath $PackageDirectory).Path
$manifest = Get-Content -LiteralPath (Join-Path $package 'manifest.json') -Raw | ConvertFrom-Json
$failures = @()
foreach ($app in $manifest.applications) {
    if ($app -eq 'Test-Windows') { continue }
    $start = [Diagnostics.ProcessStartInfo]::new()
    $start.FileName = Join-Path $package 'OpenFOAM.exe'
    $start.Arguments = "$app -help"
    $start.UseShellExecute = $false
    $start.CreateNoWindow = $true
    $start.RedirectStandardOutput = $true
    $start.RedirectStandardError = $true
    $start.EnvironmentVariables['PATH'] = "$env:WINDIR\System32;$env:WINDIR"
    $start.EnvironmentVariables['MSMPI_BIN'] = ''
    $process = [Diagnostics.Process]::Start($start)
    $stdout = $process.StandardOutput.ReadToEndAsync()
    $stderr = $process.StandardError.ReadToEndAsync()
    if (-not $process.WaitForExit(30000)) {
        $process.Kill($true)
        $process.WaitForExit()
        $failures += "${app}: help timed out"
    } elseif ($process.ExitCode -ne 0) {
        $failures += "${app}: exit $($process.ExitCode): $($stderr.GetAwaiter().GetResult())"
    }
    $null = $stdout.GetAwaiter().GetResult()
    $null = $stderr.GetAwaiter().GetResult()
    $process.Dispose()
}
if ($failures) { throw "Application startup failures:`n$($failures -join "`n")" }
Write-Output "PASS: $($manifest.applications.Count - 1) application help commands with developer tools removed from PATH."
