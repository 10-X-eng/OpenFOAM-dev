param(
    [Parameter(Mandatory)][string]$PackageDirectory,
    [string]$WorkDirectory
)
$ErrorActionPreference = 'Stop'
$package = (Resolve-Path -LiteralPath $PackageDirectory).Path
$bin = Join-Path $package 'bin'
if (-not $WorkDirectory) { $WorkDirectory = Join-Path (Split-Path $package) 'validation' }
New-Item -ItemType Directory -Path $WorkDirectory -Force | Out-Null
$WorkDirectory = (Resolve-Path -LiteralPath $WorkDirectory).Path
$oldPath = $env:PATH
$oldLocation = Get-Location
$variables = @('WM_PROJECT', 'WM_PROJECT_VERSION', 'WM_PROJECT_DIR', 'FOAM_ETC', 'FOAM_LIBBIN', 'MPI_BUFFER_SIZE')
$saved = @{}
foreach ($name in $variables) { $saved[$name] = [Environment]::GetEnvironmentVariable($name, 'Process') }
function Set-CavityPressureReference([string]$caseDirectory) {
    # pRefCell is local to rank zero and can select a different physical cell
    # after Scotch decomposition. Use the same point for both numerical runs.
    $solution = Join-Path $caseDirectory 'system/fvSolution'
    $text = Get-Content -LiteralPath $solution -Raw
    if ($text -notmatch 'pRefCell\s+0\s*;') { throw 'Cavity pressure reference was not found.' }
    ($text -replace 'pRefCell\s+0\s*;', 'pRefPoint (0.0025 0.0025 0.005);') |
        Set-Content -LiteralPath $solution -Encoding ascii
}
try {
    # Only Windows and the packaged runtime may satisfy DLL dependencies.
    $env:PATH = "$bin;$env:WINDIR\System32;$env:WINDIR"
    $env:WM_PROJECT = 'OpenFOAM'
    $env:WM_PROJECT_VERSION = 'dev'
    $env:WM_PROJECT_DIR = $package.Replace('\', '/')
    $env:FOAM_ETC = (Join-Path $package 'etc').Replace('\', '/')
    $env:FOAM_LIBBIN = $bin.Replace('\', '/')
    $env:MPI_BUFFER_SIZE = '20000000'
    & (Join-Path $bin 'Test-Windows.exe')
    if ($LASTEXITCODE) { throw "Native portability tests failed: $LASTEXITCODE" }
    & (Join-Path $bin 'Test-Windows.exe') --libraries
    if ($LASTEXITCODE) { throw "Case-distinct framework DLL loading failed: $LASTEXITCODE" }
    & (Join-Path $bin 'mpiexec.exe') -n 2 (Join-Path $bin 'Test-Windows.exe') --mpi
    if ($LASTEXITCODE) { throw "Native MPI reduction failed: $LASTEXITCODE" }
    $case = Join-Path $WorkDirectory 'smoke-cavity'
    if (Test-Path -LiteralPath $case) { throw "Test case already exists: $case" }
    New-Item -ItemType Directory -Path (Split-Path $case) -Force | Out-Null
    Copy-Item -LiteralPath (Join-Path $package 'tutorials/legacy/incompressible/icoFoam/cavity/cavity') -Destination $case -Recurse
    Set-CavityPressureReference $case
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
    & (Join-Path $package 'OpenFOAM.exe') foamToVTK -latestTime > log.foamToVTK 2>&1
    if ($LASTEXITCODE -or -not (Get-ChildItem -LiteralPath (Join-Path $case 'VTK') -Filter '*.vtk')) {
        throw 'Native launcher/VTK result export failed.'
    }
    Write-Output 'PASS: native launcher exported final CFD fields to VTK.'

    # Exercise the current modular solver, including runtime loading of its DLL.
    $moduleCase = Join-Path $WorkDirectory 'smoke-module'
    if (Test-Path -LiteralPath $moduleCase) { throw "Test case already exists: $moduleCase" }
    Copy-Item -LiteralPath (Join-Path $package 'tutorials/incompressibleFluid/cavity') -Destination $moduleCase -Recurse
    Set-Location -LiteralPath $moduleCase
    & (Join-Path $bin 'foamDictionary.exe') system/controlDict -entry endTime -set 0.05 > log.configure
    if ($LASTEXITCODE) { throw 'Cannot set modular solver test duration.' }
    & (Join-Path $bin 'blockMesh.exe') > log.blockMesh 2>&1
    if ($LASTEXITCODE) { throw 'Modular solver mesh generation failed.' }
    & (Join-Path $bin 'foamRun.exe') > log.foamRun 2>&1
    if ($LASTEXITCODE -or -not (Select-String -LiteralPath log.foamRun -Pattern '^End\s*$')) {
        throw 'The dynamically loaded incompressibleFluid solver failed.'
    }
    Write-Output 'PASS: foamRun and incompressibleFluid dynamic solver module.'

    $parallelCase = Join-Path $WorkDirectory 'smoke-parallel'
    if (Test-Path -LiteralPath $parallelCase) { throw "Test case already exists: $parallelCase" }
    Copy-Item -LiteralPath (Join-Path $package 'tutorials/legacy/incompressible/icoFoam/cavity/cavity') -Destination $parallelCase -Recurse
    Set-CavityPressureReference $parallelCase
    Set-Location -LiteralPath $parallelCase
    @'
FoamFile { format ascii; class dictionary; object decomposeParDict; }
numberOfSubdomains 2;
method scotch;
'@ | Set-Content system/decomposeParDict -Encoding ascii
    foreach ($app in @('blockMesh', 'decomposePar')) {
        & (Join-Path $bin "$app.exe") > "log.$app" 2>&1
        if ($LASTEXITCODE) { throw "Parallel setup failed: $app" }
    }
    & (Join-Path $bin 'mpiexec.exe') -n 2 (Join-Path $bin 'icoFoam.exe') -parallel > log.icoFoam 2>&1
    if ($LASTEXITCODE) { throw 'Two-rank cavity solver failed.' }
    & (Join-Path $bin 'reconstructPar.exe') -latestTime > log.reconstructPar 2>&1
    if ($LASTEXITCODE) { throw 'Parallel field reconstruction failed.' }
    foreach ($field in @('U', 'p')) {
        $path = Join-Path $parallelCase "0.5/$field"
        if (-not (Test-Path -LiteralPath $path)) { throw "Missing parallel final field: $path" }
        if (Select-String -LiteralPath $path -Pattern '\b(nan|inf)\b') { throw "Non-finite values in $path" }
        function Read-InternalField([string]$file) {
            $content = Get-Content -LiteralPath $file -Raw
            $match = [regex]::Match($content, '(?s)internalField\s+nonuniform\s+List<(scalar|vector)>\s+(\d+)\s*\((.*?)\)\s*;')
            if (-not $match.Success) { throw "Cannot read numerical internal field: $file" }
            $values = @([regex]::Matches($match.Groups[3].Value, '[+-]?(?:\d+\.?\d*|\.\d+)(?:[eE][+-]?\d+)?') | ForEach-Object {
                [double]::Parse($_.Value, [Globalization.CultureInfo]::InvariantCulture)
            })
            $components = if ($match.Groups[1].Value -eq 'vector') { 3 } else { 1 }
            if ($values.Count -ne $components * [int]$match.Groups[2].Value) { throw "Invalid field length: $file" }
            return ,$values
        }
        $serialValues = Read-InternalField (Join-Path $case "0.5/$field")
        $parallelValues = Read-InternalField $path
        if ($serialValues.Count -ne $parallelValues.Count) { throw "$field field lengths differ." }
        $maxDifference = 0.0
        for ($i = 0; $i -lt $serialValues.Count; ++$i) {
            $maxDifference = [Math]::Max($maxDifference, [Math]::Abs($serialValues[$i] - $parallelValues[$i]))
        }
        # Allow solver tolerance and six-digit ASCII output roundoff.
        if ($maxDifference -gt 1e-4) { throw "Serial/parallel $field mismatch: $maxDifference" }
        Write-Output "PASS: serial/parallel $field maximum difference $maxDifference"
    }
    Write-Output 'PASS: Scotch decomposition, two-rank cavity and field reconstruction.'
} finally {
    Set-Location $oldLocation
    $env:PATH = $oldPath
    foreach ($name in $variables) { [Environment]::SetEnvironmentVariable($name, $saved[$name], 'Process') }
}
