param([Parameter(Mandatory)][string]$PackageDirectory, [Parameter(Mandatory)][string]$ProbePath)
$ErrorActionPreference='Stop'
$package=(Resolve-Path -LiteralPath $PackageDirectory).Path
$coverage=Get-Content (Join-Path $package 'build-coverage.json') -Raw | ConvertFrom-Json
$failures=@(); $count=0
foreach($target in $coverage.targets | Where-Object {$_.type -eq 'LIB'}) {
 $dll=Join-Path (Join-Path $package 'bin') (Split-Path -Leaf $target.binary)
 $start=[Diagnostics.ProcessStartInfo]::new()
 $start.FileName=Join-Path $package 'OpenFOAM.exe'
 $start.ArgumentList.Add((Resolve-Path -LiteralPath $ProbePath).Path)
 $start.ArgumentList.Add($dll)
 $start.UseShellExecute=$false; $start.CreateNoWindow=$true
 $start.RedirectStandardOutput=$true; $start.RedirectStandardError=$true
 $start.EnvironmentVariables['PATH']="$env:WINDIR\System32;$env:WINDIR"
 $start.EnvironmentVariables['MSMPI_BIN']=''
 $p=[Diagnostics.Process]::Start($start)
 $stdout=$p.StandardOutput.ReadToEndAsync(); $stderr=$p.StandardError.ReadToEndAsync()
 if(-not $p.WaitForExit(30000)){$p.Kill($true); $p.WaitForExit(); $failures+="$dll : timeout"}
 elseif($p.ExitCode -ne 0){$failures+="$dll : exit $($p.ExitCode) $($stderr.GetAwaiter().GetResult())"}
 $null=$stdout.GetAwaiter().GetResult(); $null=$stderr.GetAwaiter().GetResult(); $p.Dispose(); $count++
}
if($failures){throw ($failures -join "`n")}
Write-Output "PASS: loaded $count OpenFOAM libraries in separate native processes."
