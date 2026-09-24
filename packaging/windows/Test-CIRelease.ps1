# Run on a disposable Windows runner: includes installation and uninstallation.
param(
    [Parameter(Mandatory)][string]$OutputDirectory,
    [Parameter(Mandatory)][string]$WorkDirectory,
    [string]$MsysRoot = 'C:\msys64'
)
$ErrorActionPreference = 'Stop'
$source = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
New-Item -ItemType Directory -Path $WorkDirectory -Force | Out-Null
$WorkDirectory = (Resolve-Path -LiteralPath $WorkDirectory).Path
& "$PSScriptRoot\Package.ps1" -OutputDirectory $OutputDirectory -MsysRoot $MsysRoot *> "$WorkDirectory\package.log"
$revision = (& git -C $source rev-parse --short=12 HEAD).Trim()
if ($LASTEXITCODE) { throw 'Cannot read source revision.' }
$package = Join-Path $OutputDirectory "OpenFOAM-dev-windows-x64-$revision"
$probes = Join-Path $WorkDirectory 'test tools'
& "$PSScriptRoot\Build-TestTools.ps1" -OutputDirectory $probes -MsysRoot $MsysRoot
& "$PSScriptRoot\SmokeTest.ps1" -PackageDirectory $package -WorkDirectory "$WorkDirectory\portable cases" *> "$WorkDirectory\portable.log"
& "$PSScriptRoot\Test-Applications.ps1" -PackageDirectory $package *> "$WorkDirectory\applications.log"
& "$PSScriptRoot\Test-AllLibraries.ps1" -PackageDirectory $package -ProbePath "$probes\load-library.exe" *> "$WorkDirectory\libraries.log"
& "$PSScriptRoot\Test-Launcher.ps1" -PackageDirectory $package -ProbePath "$probes\launcher-arguments.exe" -WorkDirectory "$probes\caller directory" *> "$WorkDirectory\launcher.log"
& python -c 'import sys,zipfile; z=zipfile.ZipFile(sys.argv[1]); bad=z.testzip(); assert bad is None,bad; print("PASS: ZIP CRC",len(z.infolist()),"entries")' "$package.zip" *> "$WorkDirectory\zip.log"
if ($LASTEXITCODE) { throw 'ZIP CRC validation failed.' }
& "$PSScriptRoot\MakeInstaller.ps1" -PackageDirectory $package -MsysRoot $MsysRoot *> "$WorkDirectory\installer-build.log"
& "$PSScriptRoot\Test-Installer.ps1" -Installer "$package-Setup.exe" -InstallDirectory "$WorkDirectory\installed OpenFOAM" -ProbeDirectory $probes *> "$WorkDirectory\installer.log"
Write-Output 'PASS: standalone runtime and installer lifecycle.'

$rattler = Join-Path $WorkDirectory 'rattler-build.exe'
Invoke-WebRequest 'https://github.com/prefix-dev/rattler-build/releases/download/v0.76.1/rattler-build-x86_64-pc-windows-msvc.exe' -OutFile $rattler
if ((Get-FileHash $rattler -Algorithm SHA256).Hash -ne '131e3d9e6d67e7b5e873627567e74708e1722a40e78bcd3619dc4b20906fbb64') { throw 'Rattler checksum mismatch.' }
$env:OPENFOAM_PACKAGE = $package
$env:OPENFOAM_REVISION = $revision
$run = if ($env:GITHUB_RUN_NUMBER) { $env:GITHUB_RUN_NUMBER } else { '0' }
$env:OPENFOAM_VERSION = "$((Get-Date).ToUniversalTime().ToString('yyyy.M.d')).$run"
& $rattler build -r "$PSScriptRoot\rattler\recipe.yaml" --output-dir "$WorkDirectory\rattler" --log-style plain --color never *> "$WorkDirectory\rattler.log"
if ($LASTEXITCODE) { throw 'Rattler build or tests failed.' }
Copy-Item "$WorkDirectory\rattler\win-64\*.conda" $OutputDirectory
$files = @(Get-ChildItem -LiteralPath $OutputDirectory -File | Where-Object { $_.Name -match '(\.zip|\.tar\.gz|\.conda|-Setup\.exe)$' })
if ($files.Count -ne 4) { throw 'Expected installer, ZIP, source archive and Conda package.' }
$files | Sort-Object Name | ForEach-Object {
    "$((Get-FileHash $_.FullName -Algorithm SHA256).Hash.ToLowerInvariant())  $($_.Name)"
} | Set-Content (Join-Path $OutputDirectory 'SHA256SUMS.txt')
Copy-Item (Join-Path $package 'manifest.json'),(Join-Path $package 'build-coverage.json') $OutputDirectory
if ($env:GITHUB_STEP_SUMMARY) {
    @"
Native Windows packages built from $revision.

Passed: full source build; application and DLL startup checks; serial and two-rank MPI CFD; VTK export; dynamic code compilation; installer install/run/uninstall with spaces in paths; Rattler tests.

Download **windows-native-packages** for Setup.exe, portable ZIP, Conda package, matching source and SHA256SUMS.txt. Logs are in **windows-native-validation**. Artifacts are retained for 14 days.
"@ >> $env:GITHUB_STEP_SUMMARY
}
Write-Output 'PASS: all four release artifacts validated and checksummed.'
