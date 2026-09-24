param(
    [Parameter(Mandatory)][string]$Installer,
    [Parameter(Mandatory)][string]$InstallDirectory,
    [Parameter(Mandatory)][string]$ProbeDirectory
)
$ErrorActionPreference = 'Stop'
if (Test-Path -LiteralPath $InstallDirectory) { throw 'Installer test destination must be new.' }
if (Test-Path 'HKCU:\Software\OpenFOAM-native') { throw 'An existing installation is registered; leave it intact.' }
$installerPath = (Resolve-Path -LiteralPath $Installer).Path
$data = [Text.Encoding]::ASCII.GetString([IO.File]::ReadAllBytes($installerPath))
if ($data -notmatch 'requestedExecutionLevel level="asInvoker"' -or $data -match 'requestedExecutionLevel level="requireAdministrator"') {
    throw 'Installer execution-level manifest is not asInvoker.'
}
$process = Start-Process -FilePath $installerPath -ArgumentList @('/S', "/D=$InstallDirectory") -WindowStyle Hidden -PassThru -Wait
if ($process.ExitCode -ne 0) { throw "Silent install failed: $($process.ExitCode)" }
if (-not (Test-Path -LiteralPath (Join-Path $InstallDirectory 'OpenFOAM.exe'))) { throw 'Launcher not installed.' }
Write-Output 'PASS: per-user silent installer completed with asInvoker manifest'
$installedFiles = @(Get-ChildItem -LiteralPath $InstallDirectory -File -Recurse |
    Where-Object { $_.Name -ne 'Uninstall.exe' } | ForEach-Object FullName)
& (Join-Path $PSScriptRoot 'SmokeTest.ps1') -PackageDirectory $InstallDirectory -WorkDirectory "$InstallDirectory-validation"
& (Join-Path $PSScriptRoot 'Test-Applications.ps1') -PackageDirectory $InstallDirectory
& (Join-Path $PSScriptRoot 'Test-AllLibraries.ps1') -PackageDirectory $InstallDirectory -ProbePath (Join-Path $ProbeDirectory 'load-library.exe')
& (Join-Path $PSScriptRoot 'Test-Launcher.ps1') -PackageDirectory $InstallDirectory -ProbePath (Join-Path $ProbeDirectory 'launcher-arguments.exe') -WorkDirectory (Join-Path $ProbeDirectory 'caller directory')
$preserved = Join-Path $InstallDirectory 'user-created-file.txt'
'Keep user files during uninstall.' | Set-Content -LiteralPath $preserved
$uninstaller = Join-Path $InstallDirectory 'Uninstall.exe'
$process = Start-Process -FilePath $uninstaller -ArgumentList @('/S', "_?=$InstallDirectory") -WindowStyle Hidden -PassThru -Wait
if ($process.ExitCode -ne 0) { throw "Silent uninstall failed: $($process.ExitCode)" }
if (Test-Path -LiteralPath (Join-Path $InstallDirectory 'OpenFOAM.exe')) { throw 'Uninstall did not remove the launcher.' }
if (-not (Test-Path -LiteralPath $preserved)) { throw 'Uninstall removed a user-created file.' }
foreach ($file in $installedFiles) {
    if (Test-Path -LiteralPath $file) { throw "Uninstall left an installed file: $file" }
}
if (Test-Path 'HKCU:\Software\OpenFOAM-native') { throw 'Uninstall left its registration behind.' }
if (Test-Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\OpenFOAM-native') { throw 'Uninstall left its Apps registration behind.' }
Write-Output 'PASS: silent uninstall removed installed files and preserved a user-created file'
