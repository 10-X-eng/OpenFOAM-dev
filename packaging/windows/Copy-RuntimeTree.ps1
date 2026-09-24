param(
    [Parameter(Mandatory)][string]$SourceRoot,
    [Parameter(Mandatory)][string]$Destination
)
$ErrorActionPreference = 'Stop'
$source = (Resolve-Path -LiteralPath $SourceRoot).Path.TrimEnd('\', '/')
$links = [Collections.Generic.Dictionary[string,string]]::new([StringComparer]::Ordinal)
# A Windows Git checkout can represent symlinks as small text files. Export the
# referenced contents, including directory links, without needing elevation.
$entries = & git -C $source -c core.quotepath=false ls-files --stage
if ($LASTEXITCODE) { throw 'Cannot enumerate source symlinks.' }
foreach ($entry in $entries) {
    if ($entry -match '^120000 ([0-9a-f]+) 0\t(.+)$') {
        $blob = $Matches[1]
        $relative = $Matches[2]
        $target = & git -C $source cat-file blob $blob
        if ($LASTEXITCODE) { throw "Cannot read symlink $relative" }
        $links.Add($relative, ($target -join "`n").TrimEnd("`r", "`n"))
    }
}
function Copy-Resolved([string]$relative, [string]$output, [string[]]$ancestors) {
    if ($relative -eq 'bin/wmake.cmd') { return } # Source SDK only
    if ($ancestors -ccontains $relative) { throw "Cyclic source link: $relative" }
    $inputPath = Join-Path $source $relative
    $nextAncestors = @($ancestors) + $relative
    if ($links.ContainsKey($relative)) {
        $target = [IO.Path]::GetFullPath((Join-Path (Split-Path -Parent $inputPath) $links[$relative]))
        if (-not $target.StartsWith($source + '\', [StringComparison]::OrdinalIgnoreCase)) {
            throw "Source link escapes checkout: $relative"
        }
        Copy-Resolved $target.Substring($source.Length + 1).Replace('\', '/') $output $nextAncestors
    } elseif (Test-Path -LiteralPath $inputPath -PathType Container) {
        New-Item -ItemType Directory -Path $output -Force | Out-Null
        foreach ($child in Get-ChildItem -LiteralPath $inputPath -Force) {
            Copy-Resolved ($relative + '/' + $child.Name) (Join-Path $output $child.Name) $nextAncestors
        }
    } elseif (Test-Path -LiteralPath $inputPath -PathType Leaf) {
        Copy-Item -LiteralPath $inputPath -Destination $output -Force
    } else {
        throw "Missing source link target: $relative"
    }
}
foreach ($root in @('bin', 'etc', 'tutorials')) {
    Copy-Resolved $root (Join-Path $Destination $root) @()
}
