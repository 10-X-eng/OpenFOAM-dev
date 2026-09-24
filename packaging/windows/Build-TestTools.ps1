param([Parameter(Mandatory)][string]$OutputDirectory, [string]$MsysRoot = 'C:\msys64')
$ErrorActionPreference = 'Stop'
New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null
$toolchain = Join-Path $MsysRoot 'ucrt64/bin'
$compiler = Join-Path $toolchain 'g++.exe'
$resource = Join-Path $OutputDirectory 'application.o'
$oldPath = $env:PATH
try {
    $env:PATH = "$toolchain;$oldPath"
    & (Join-Path $toolchain 'windres.exe') -I $PSScriptRoot (Join-Path $PSScriptRoot 'application.rc') $resource
    if ($LASTEXITCODE) { throw 'Cannot compile the asInvoker manifest.' }
    foreach ($name in @('load-library', 'launcher-arguments')) {
        & $compiler -std=c++17 -O2 -municode -static (Join-Path $PSScriptRoot "test-tools/$name.cpp") $resource -o (Join-Path $OutputDirectory "$name.exe")
        if ($LASTEXITCODE) { throw "Cannot compile test probe: $name" }
    }
} finally {
    $env:PATH = $oldPath
}
