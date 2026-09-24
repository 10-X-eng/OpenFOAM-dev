param([Parameter(Mandatory)][string]$SourceRoot)
$ErrorActionPreference = 'Stop'
$platform = Join-Path $SourceRoot 'platforms/mingw64GccDPInt32Opt'
$targets = @()
$excluded = @()
$missing = @()
$files = & git -C $SourceRoot ls-files
if ($LASTEXITCODE) { throw 'Cannot enumerate upstream build targets.' }
foreach ($file in $files) {
    if ($file -notmatch '^(src/|applications/(solvers|modules|legacy|utilities)/).*/Make/files$') { continue }
    $text = Get-Content -LiteralPath (Join-Path $SourceRoot $file) -Raw
    if ($text -notmatch '(?m)^(LIB|EXE)\s*=\s*(.+)$') { continue }
    $kind = $Matches[1]
    $target = $Matches[2].Trim()
    $reason = $null
    if ($file -match '^src/OSspecific/') { $reason = 'Platform implementation is linked into OpenFOAM.' }
    elseif ($file -match '^src/Pstream/') { $reason = 'Real MPI backend is linked into OpenFOAM; serial stubs are unnecessary.' }
    elseif ($file -match '^src/dummyThirdParty/') { $reason = 'Use real third-party implementations instead of diagnostic stubs.' }
    elseif ($file -match '^src/renumber/SloanRenumber/') { $reason = 'Deprecated and disabled in upstream Allwmake.' }
    elseif ($file -match '^src/fvAgglomerationMethods/MGridGenGamgAgglomeration/') { $reason = 'Optional ParMGridGen is no longer supplied by upstream ThirdParty-dev.' }
    elseif ($file -match '/PVReaders/') { $reason = 'Optional ParaView SDK plugins; foamToVTK supplies interoperable output.' }
    elseif ($file -match '/foamToTecplot360/') { $reason = 'Optional TecIO SDK is not supplied by upstream ThirdParty-dev.' }
    elseif ($file -match '/Optional/ccm26ToFoam/') { $reason = 'Optional libccmio SDK and its build script are not supplied by upstream ThirdParty-dev.' }
    if ($reason) {
        $excluded += @{ source = $file; reason = $reason }
        continue
    }
    $path = $target.Replace('$(FOAM_APPBIN)', (Join-Path $platform 'bin')).Replace('$(FOAM_LIBBIN)', (Join-Path $platform 'lib')).Replace('$(FOAM_MPI)', 'msmpi')
    $path += $(if ($kind -eq 'EXE') { '.exe' } else { '.dll' })
    $path = $path -creplace 'libLagrangian\.dll$', 'libLagrangianFramework.dll'
    $path = $path -creplace 'libLagrangianFunctionObjects\.dll$', 'libLagrangianFrameworkFunctionObjects.dll'
    if ($path.Contains('$(')) { throw "Unresolved build target: $target ($file)" }
    if (-not (Test-Path -LiteralPath $path) -or (Get-Item -LiteralPath $path).Length -eq 0) {
        $missing += "$file => $path"
    }
    $targets += @{ source = $file; binary = $path.Substring($platform.Length + 1); type = $kind }
}
if ($missing.Count) { throw "Missing $($missing.Count) required build targets:`n$($missing -join "`n")" }
[ordered]@{ targets = $targets; exclusions = $excluded } | ConvertTo-Json -Depth 5
