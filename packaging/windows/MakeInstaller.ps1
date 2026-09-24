param(
    [Parameter(Mandatory)][string]$PackageDirectory,
    [string]$MsysRoot = 'C:\msys64'
)
$ErrorActionPreference = 'Stop'
$package = (Resolve-Path -LiteralPath $PackageDirectory).Path
$manifest = Get-Content -LiteralPath (Join-Path $package 'manifest.json') -Raw | ConvertFrom-Json
$revision = $manifest.revision.Substring(0, 12)
$output = Split-Path -Parent $package
$source = Join-Path $output "OpenFOAM-dev-source-$revision.tar.gz"
if (-not (Test-Path -LiteralPath $source)) { throw 'Matching source archive is missing.' }
$uninstall = Join-Path $output "uninstall-files-$revision.nsh"
# Escape NSIS strings; the installer removes only files it installed.
function Escape-Nsis([string]$text) { $text.Replace('$', '$$').Replace('"', '$\"') }
$lines = @(Get-ChildItem -LiteralPath $package -File -Recurse | ForEach-Object {
    'Delete "$INSTDIR\' + (Escape-Nsis $_.FullName.Substring($package.Length + 1)) + '"'
})
$lines += @(Get-ChildItem -LiteralPath $package -Directory -Recurse |
    Sort-Object { $_.FullName.Length } -Descending | ForEach-Object {
        'RMDir "$INSTDIR\' + (Escape-Nsis $_.FullName.Substring($package.Length + 1)) + '"'
    })
$lines | Set-Content -LiteralPath $uninstall -Encoding utf8
$exe = Join-Path $output "OpenFOAM-dev-windows-x64-$revision-Setup.exe"
& (Join-Path $MsysRoot 'ucrt64/bin/makensis.exe') /V2 "/DPACKAGE_DIR=$package" "/DOUTPUT_EXE=$exe" "/DREVISION=$revision" "/DUNINSTALL_FILES=$uninstall" "/DSOURCE_ARCHIVE=$source" "/DSOURCE_NAME=$(Split-Path -Leaf $source)" (Join-Path $PSScriptRoot 'installer.nsi')
if ($LASTEXITCODE) { throw 'Installer compilation failed.' }
Get-FileHash -LiteralPath $exe -Algorithm SHA256
