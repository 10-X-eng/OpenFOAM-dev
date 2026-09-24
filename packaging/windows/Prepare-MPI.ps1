param([Parameter(Mandatory)][string]$Destination)
$ErrorActionPreference = 'Stop'
# Conda-forge builds Microsoft's MIT-licensed MPI sources as an app-local
# runtime. These three programs import Windows system DLLs only and do not
# require registering a service or running the administrator-only MSI setup.
$name = 'msmpi-10.1.1-h571195b_8'
$hash = '1805d513b0e54b728842aca820b60d717d102f45d2bdd7396a112c3a8420220c'
New-Item -ItemType Directory -Path $Destination -Force | Out-Null
$destination = (Resolve-Path -LiteralPath $Destination).Path
$archive = Join-Path $destination "$name.conda"
if (-not (Test-Path -LiteralPath $archive)) {
    Invoke-WebRequest -Uri "https://conda.anaconda.org/conda-forge/win-64/$name.conda" -OutFile $archive
}
if ((Get-FileHash -LiteralPath $archive -Algorithm SHA256).Hash.ToLowerInvariant() -ne $hash) {
    throw 'Microsoft MPI package checksum mismatch.'
}
& "$env:WINDIR\System32\tar.exe" -xf $archive -C $destination
if ($LASTEXITCODE) { throw 'Cannot extract MPI package.' }
foreach ($part in @('pkg', 'info')) {
    & "$env:WINDIR\System32\tar.exe" -xf (Join-Path $destination "$part-$name.tar.zst") -C $destination
    if ($LASTEXITCODE) { throw "Cannot extract MPI $part payload." }
}
