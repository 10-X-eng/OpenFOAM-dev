param(
    [Parameter(Mandatory)][string]$OutputDirectory,
    [string]$MsysRoot = 'C:\msys64'
)
$ErrorActionPreference = 'Stop'
$sourceRoot = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$platform = Join-Path $sourceRoot 'platforms/mingw64GccDPInt32Opt'
$revision = (& git -C $sourceRoot rev-parse --short=12 HEAD).Trim()
if ($LASTEXITCODE) { throw 'Cannot read the source revision.' }
$dirty = & git -C $sourceRoot status --porcelain
if ($dirty) { throw 'Commit source changes before packaging so the source archive matches the binaries.' }
$package = Join-Path $OutputDirectory "OpenFOAM-dev-windows-x64-$revision"
if (Test-Path -LiteralPath $package) { throw "Output already exists: $package" }
$bin = Join-Path $package 'bin'
New-Item -ItemType Directory -Path $bin -Force | Out-Null
$applications = @('blockMesh', 'checkMesh', 'icoFoam', 'foamDictionary', 'Test-Windows')
foreach ($app in $applications) {
    Copy-Item -LiteralPath (Join-Path $platform "bin/$app.exe") -Destination $bin
}
Copy-Item -Path (Join-Path $platform 'lib/*.dll') -Destination $bin

# Collect the transitive MinGW DLL dependencies and fail if a non-system DLL
# is missing. Never package MSYS/Cygwin, a compiler, or unrelated installed DLLs.
$queue = [Collections.Generic.Queue[string]]::new()
Get-ChildItem -LiteralPath $bin -File | ForEach-Object { $queue.Enqueue($_.FullName) }
$seen = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
$objdump = Join-Path $MsysRoot 'ucrt64/bin/objdump.exe'
while ($queue.Count) {
    $binary = $queue.Dequeue()
    if (-not $seen.Add($binary)) { continue }
    $headers = & $objdump -p $binary
    if ($LASTEXITCODE) { throw "Cannot inspect $binary" }
    foreach ($line in $headers) {
        if ($line -notmatch 'DLL Name:\s+(\S+)') { continue }
        $name = $Matches[1]
        if ($name -match '^(msys-|cyg)') { throw "Non-native runtime dependency: $name" }
        $destination = Join-Path $bin $name
        if (Test-Path -LiteralPath $destination) { continue }
        $runtime = Join-Path $MsysRoot "ucrt64/bin/$name"
        if (Test-Path -LiteralPath $runtime) {
            Copy-Item -LiteralPath $runtime -Destination $destination
            $queue.Enqueue($destination)
        } elseif ($name -match '^(api-ms-|ext-ms-)' -or (Test-Path -LiteralPath (Join-Path $env:WINDIR "System32/$name"))) {
            continue
        } else { throw "Missing DLL dependency: $name ($binary)" }
    }
}
Copy-Item -LiteralPath (Join-Path $sourceRoot 'etc') -Destination $package -Recurse
Copy-Item -LiteralPath (Join-Path $sourceRoot 'COPYING') -Destination $package
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'OpenFOAM.cmd') -Destination $package
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'README.md') -Destination $package
$tutorials = Join-Path $package 'tutorials'
New-Item -ItemType Directory -Path $tutorials | Out-Null
Copy-Item -LiteralPath (Join-Path $sourceRoot 'tutorials/legacy/incompressible/icoFoam/cavity/cavity') -Destination $tutorials -Recurse
$licenseDestination = Join-Path $package 'runtime-licenses'
Copy-Item -LiteralPath (Join-Path $MsysRoot 'ucrt64/share/licenses') -Destination $licenseDestination -Recurse
$manifest = [ordered]@{
    source = 'https://github.com/10-X-eng/OpenFOAM-dev'
    revision = (& git -C $sourceRoot rev-parse HEAD).Trim()
    compiler = (& (Join-Path $MsysRoot 'ucrt64/bin/g++.exe') --version | Select-Object -First 1)
    architecture = 'Windows x64 PE, UCRT'
    precision = 'double'
    labels = 32
    parallel = $false
    applications = $applications
    files = @(Get-ChildItem -LiteralPath $bin -File | ForEach-Object {
        @{ name = $_.Name; sha256 = (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash }
    })
}
$manifest | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $package 'manifest.json') -Encoding utf8
$sourceArchive = Join-Path $OutputDirectory "OpenFOAM-dev-source-$revision.tar.gz"
& git -C $sourceRoot archive --format=tar.gz --output=$sourceArchive HEAD
if ($LASTEXITCODE) { throw 'Cannot create the corresponding source archive.' }
$zip = "$package.zip"
Compress-Archive -LiteralPath $package -DestinationPath $zip
Get-FileHash -LiteralPath $zip -Algorithm SHA256
Write-Output $zip
