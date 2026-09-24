# OpenFOAM-dev for native Windows x64

This port builds the OpenFOAM Foundation development branch as Windows PE
executables and DLLs using MinGW-w64 UCRT. The solvers do not require WSL,
a Linux kernel, Docker, MSYS or Cygwin. MSYS2 is used to compile the source.

## Install and run

Run `OpenFOAM-dev-windows-x64-REVISION-Setup.exe`. Setup installs for the current
user, adds a Start menu entry and an uninstaller, and bundles Microsoft MPI
locally. It does not request administrator privileges or install system services.

Open **OpenFOAM** from the Start menu, or run `OpenFOAM.exe`. This opens a terminal
configured for the installed tools, with cases under `Documents/OpenFOAM/run`.
From an existing terminal, `OpenFOAM.exe foamRun -help` runs a command and returns
its exit code without changing the caller's directory or environment.

Example (inside the OpenFOAM terminal):

```bat
xcopy "%FOAM_TUTORIALS%\legacy\incompressible\icoFoam\cavity\cavity" cavity /E /I
cd cavity
blockMesh
checkMesh
icoFoam
```

For a decomposed case, use `mpiexec -n 4 foamRun -parallel`. Microsoft MPI is
included in the standalone installer. The Conda package uses the `msmpi`
dependency from conda-forge instead.

The ZIP contains the same portable runtime and `OpenFOAM.exe`; extract it and
run the launcher. Cases belong outside the installation, so uninstalling does
not remove them. All upstream tutorials and command helper scripts are included.
Their Unix scripts need a configured shell; individual solver and utility
executables run directly on Windows.

## Build coverage

The build follows the upstream `src/Allwmake` and `applications/Allwmake` lists,
including the current solver modules, legacy solvers and utilities. It uses
real MPI, Scotch, PT-Scotch, METIS, ParMETIS and Zoltan rather than serial or
partitioner stubs. Every expected binary is checked before packaging; the exact
inventory and exclusions are recorded in `build-coverage.json`.

Upstream's disabled Sloan renumberer, optional ParMGridGen agglomerator (whose
source is no longer in ThirdParty-dev), ParaView SDK reader plugins, and the
TecIO-dependent Tecplot exporter and libccmio-dependent CCM importer are outside
the standard build. ParaView is a
separate application; `foamToVTK`
provides interoperable visualization output. Runtime compilation of user code
requires a configured native build toolchain; the runtime package is not a
compiler/SDK installation.

The supported binary configuration is Windows x64, double precision and 32-bit
labels. The two upstream Lagrangian frameworks receive distinct native DLL
filenames because the Windows loader cannot distinguish names by case. The
loader translates the original dictionary names automatically.

## Build from source

Use a short NTFS checkout path. Upstream has case-distinct source files and
folders. Enable case sensitivity on the empty parent **before cloning** (this
source-build preparation can require administrator rights):

```powershell
New-Item -ItemType Directory C:\of-build
fsutil.exe file setCaseSensitiveInfo C:\of-build enable
git -c core.longpaths=true -c core.autocrlf=false clone --branch windows-native https://github.com/10-X-eng/OpenFOAM-dev.git C:\of-build\OpenFOAM-dev
git -C C:\of-build\OpenFOAM-dev config core.ignorecase false
```

In an updated MSYS2 installation:

```sh
pacman -S --needed git gcc make flex bison util-linux \
  mingw-w64-ucrt-x86_64-gcc mingw-w64-ucrt-x86_64-zlib \
  mingw-w64-ucrt-x86_64-libsystre mingw-w64-ucrt-x86_64-msmpi \
  mingw-w64-ucrt-x86_64-metis mingw-w64-ucrt-x86_64-parmetis \
  mingw-w64-ucrt-x86_64-scotch mingw-w64-ucrt-x86_64-boost \
  mingw-w64-ucrt-x86_64-nsis
cd /c/of-build/OpenFOAM-dev
JOBS=8 bash packaging/windows/build.sh
```

The script fetches a pinned ThirdParty-dev revision and builds Zoltan. Dependency
scanning uses MSYS GCC; CFD code uses native UCRT GCC. The runtimes are not mixed.
The build stops at the first error and writes a completion marker only when all
standard targets and the launcher have built successfully.

## Package and validate

Commit source changes, run the full build, then use PowerShell:

```powershell
./packaging/windows/Package.ps1 -OutputDirectory C:\of-packages
./packaging/windows/SmokeTest.ps1 -PackageDirectory C:\of-packages\OpenFOAM-dev-windows-x64-REVISION
./packaging/windows/Test-Applications.ps1 -PackageDirectory C:\of-packages\OpenFOAM-dev-windows-x64-REVISION
./packaging/windows/MakeInstaller.ps1 -PackageDirectory C:\of-packages\OpenFOAM-dev-windows-x64-REVISION
```

Packaging includes the corresponding source archive, licenses, revision and
binary checksums. MPI's portable package is pinned and SHA-256 verified. The
packager recursively checks imported DLLs and rejects MSYS/Cygwin dependencies.
The smoke test uses only the package and Windows on PATH. It checks portability,
coexisting Lagrangian DLLs, a two-rank MPI reduction, a complete cavity run,
`foamRun` module loading, Scotch decomposition and a parallel CFD run followed by
field reconstruction.

`Test-Applications.ps1` requires PowerShell 7 and checks startup of every packaged
application. In the MSYS2 build shell, `bash packaging/windows/Test-DynamicCode.sh`
checks native `#codeStream` compilation, DLL loading and cached reuse. This test
uses a trusted generated dictionary and keeps the upstream code-execution checks.

The Rattler recipe is `packaging/windows/rattler/recipe.yaml`. Set
`OPENFOAM_PACKAGE` to the staged package directory, `OPENFOAM_VERSION` to a
Conda-compatible version, and `OPENFOAM_REVISION` to the Git revision, then run:

```powershell
rattler-build build -r packaging/windows/rattler/recipe.yaml
```

## GitHub Actions

The `Native Windows installer` workflow builds pushes to `windows-native` on a
fresh Windows 2022 runner. It can also be dispatched manually once registered
on the repository's default branch. No binaries from a developer machine are
used. The compiler and dependency versions are recorded in the validation logs.

Successful runs upload `windows-native-packages`: the installer EXE, portable
ZIP, matching source archive, Rattler/Conda package, manifests and SHA-256
checksums. The packages are uploaded only after the runtime and actual installer
pass the CFD/MPI, application, DLL, launcher and uninstall checks. Installer and
case paths deliberately contain spaces. Logs are uploaded separately as
`windows-native-validation`, including when a build fails. Artifacts are retained
for 14 days; the workflow does not publish a GitHub Release.

`Test-CIRelease.ps1` runs the same packaging gates on a disposable Windows host.
It refuses to replace an existing registered OpenFOAM installation. The test
helpers are built with `Build-TestTools.ps1`; their child processes run with the
development toolchain removed from PATH.

## Provenance

The Windows OS implementation was adapted from
[blueCFD-Core-12](https://github.com/blueCFD/OpenFOAM-dev/tree/cdafd0c844875c0a8504fc254ab35372c568a1e4/src/OSspecific/MSwindows),
commit `cdafd0c844875c0a8504fc254ab35372c568a1e4`. Original OpenFOAM, Symscape and
blueCAPE copyright notices are retained. OpenFOAM and this port are licensed
GPL-3.0-or-later; see `COPYING`. Bundled dependencies retain their own licenses.
