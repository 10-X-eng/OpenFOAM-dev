param([Parameter(Mandatory)][string]$PackageDirectory)
$ErrorActionPreference = 'Stop'
$package = (Resolve-Path -LiteralPath $PackageDirectory).Path
$bin = Join-Path $package 'bin'
$oldPath = $env:PATH
$oldLocation = Get-Location
$variables = @('WM_PROJECT', 'WM_PROJECT_VERSION', 'WM_PROJECT_DIR', 'FOAM_ETC', 'FOAM_LIBBIN')
$saved = @{}
foreach ($name in $variables) { $saved[$name] = [Environment]::GetEnvironmentVariable($name, 'Process') }
try {
    # Only Windows and the packaged runtime may satisfy DLL dependencies.
    $env:PATH = "$bin;$env:WINDIR\System32;$env:WINDIR"
    $env:WM_PROJECT = 'OpenFOAM'
    $env:WM_PROJECT_VERSION = 'dev'
    $env:WM_PROJECT_DIR = $package.Replace('\', '/')
    $env:FOAM_ETC = (Join-Path $package 'etc').Replace('\', '/')
    $env:FOAM_LIBBIN = $bin.Replace('\', '/')
    & (Join-Path $bin 'Test-Windows.exe')
    if ($LASTEXITCODE) { throw "Native portability tests failed: $LASTEXITCODE" }
    $case = Join-Path $package 'run/smoke-cavity'
    if (Test-Path -LiteralPath $case) { throw "Test case already exists: $case" }
    New-Item -ItemType Directory -Path (Split-Path $case) -Force | Out-Null
    Copy-Item -LiteralPath (Join-Path $package 'tutorials/cavity') -Destination $case -Recurse
    Set-Location -LiteralPath $case
    foreach ($app in @('blockMesh', 'checkMesh', 'icoFoam')) {
        & (Join-Path $bin "$app.exe") 2>&1 | Out-File "log.$app" -Encoding utf8
        if ($LASTEXITCODE) { throw "$app failed with exit code $LASTEXITCODE. See $case/log.$app" }
    }
    if (-not (Select-String -LiteralPath 'log.checkMesh' -SimpleMatch 'Mesh OK.')) { throw 'Mesh validation did not pass.' }
    if (-not (Select-String -LiteralPath 'log.icoFoam' -Pattern '^End\s*$')) { throw 'Solver did not finish.' }
    foreach ($field in @('U', 'p')) {
        $path = Join-Path $case "0.5/$field"
        if (-not (Test-Path -LiteralPath $path)) { throw "Missing final field: $path" }
        if (Select-String -LiteralPath $path -Pattern '\b(nan|inf)\b') { throw "Non-finite values in $path" }
    }
    Write-Output "PASS: Windows-only runtime, mesh validation, and 100 cavity solver steps. Logs: $case"
} finally {
    Set-Location $oldLocation
    $env:PATH = $oldPath
    foreach ($name in $variables) { [Environment]::SetEnvironmentVariable($name, $saved[$name], 'Process') }
}
