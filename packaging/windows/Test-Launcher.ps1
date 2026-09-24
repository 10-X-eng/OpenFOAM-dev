param([Parameter(Mandatory)][string]$PackageDirectory, [Parameter(Mandatory)][string]$ProbePath, [Parameter(Mandatory)][string]$WorkDirectory)
$ErrorActionPreference = 'Stop'
$package = (Resolve-Path -LiteralPath $PackageDirectory).Path
$start = [Diagnostics.ProcessStartInfo]::new()
$start.FileName = Join-Path $package 'OpenFOAM.exe'
$start.WorkingDirectory = (New-Item -ItemType Directory -Path $WorkDirectory -Force).FullName
foreach ($argument in @((Resolve-Path -LiteralPath $ProbePath).Path, 'with spaces', '', 'quote"and\tail\', $start.WorkingDirectory, $package)) {
    $start.ArgumentList.Add($argument)
}
$start.UseShellExecute = $false
$start.CreateNoWindow = $true
$start.RedirectStandardOutput = $true
$start.RedirectStandardError = $true
$start.EnvironmentVariables['PATH'] = "$env:WINDIR\System32;$env:WINDIR"
$start.EnvironmentVariables['MSMPI_BIN'] = ''
$process = [Diagnostics.Process]::Start($start)
$stdout = $process.StandardOutput.ReadToEndAsync()
$stderr = $process.StandardError.ReadToEndAsync()
if (-not $process.WaitForExit(30000)) { $process.Kill($true); throw 'Launcher timed out.' }
$text = $stdout.GetAwaiter().GetResult()
$errorText = $stderr.GetAwaiter().GetResult()
if ($process.ExitCode -ne 37) { throw "Launcher failed: $($process.ExitCode) $errorText" }
$process.Dispose()
Write-Output $text.Trim()
Write-Output 'PASS: child exit code 37 propagated unchanged'
