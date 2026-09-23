# OpenFOAM-dev for Windows x64

This port builds Windows PE executables and DLLs with MinGW-w64 UCRT.
MSYS2 supplies the compiler and build tools. WSL, a Linux kernel, Docker,
and the MSYS runtime are not used by the packaged solver executables.

The initial package targets **double precision, 32-bit labels, serial CFD**:
`blockMesh`, `checkMesh`, `icoFoam`, and `foamDictionary`. It is not a complete
replacement for the upstream distribution. MPI, ParaView, runtime compilation,
and the remaining solver modules are not included or validated.

## Run the package

Extract the ZIP to a local directory and open `OpenFOAM.cmd`. In the terminal:

```bat
xcopy "%FOAM_TUTORIALS%\cavity" cavity /E /I
cd cavity
blockMesh
checkMesh
icoFoam
```

The cavity tutorial runs 100 time steps to time 0.5. The final velocity and
pressure fields are in `cavity/0.5`. A native Windows ParaView installation can
be used separately for visualization.

## Package and verify

After building, run these from PowerShell, using a new output directory:

```powershell
./packaging/windows/Package.ps1 -OutputDirectory C:\of-packages
./packaging/windows/SmokeTest.ps1 -PackageDirectory C:\of-packages\OpenFOAM-dev-windows-x64-REVISION
```

Packaging requires a clean Git commit, generates the matching source archive,
and checks transitive DLL imports. The smoke test removes developer tools from
the process PATH, runs portability regression tests, checks the generated mesh,
and completes the cavity simulation. Build and test logs should be retained
with the package. The GitHub Actions workflow runs these same steps on Windows.

## Build

Use a short checkout path on NTFS. Upstream contains case-distinct source
files and directories, so enable case sensitivity on the empty parent
directory **before cloning**, using an elevated PowerShell if necessary:

```powershell
New-Item -ItemType Directory C:\of-build
fsutil.exe file setCaseSensitiveInfo C:\of-build enable
git -c core.longpaths=true -c core.autocrlf=false clone --branch windows-native https://github.com/10-X-eng/OpenFOAM-dev.git C:\of-build\OpenFOAM-dev
git -C C:\of-build\OpenFOAM-dev config core.longpaths true
git -C C:\of-build\OpenFOAM-dev config core.ignorecase false
```

Install MSYS2, update it following its normal update procedure, and install:

```sh
pacman -S --needed git gcc make flex bison \
  mingw-w64-ucrt-x86_64-gcc mingw-w64-ucrt-x86_64-zlib \
  mingw-w64-ucrt-x86_64-libsystre
```

From an MSYS2 shell:

```sh
cd /c/of-build/OpenFOAM-dev
JOBS=8 bash packaging/windows/build.sh
```

Build tools use MSYS GCC to preserve POSIX paths in dependency files. CFD
code uses UCRT MinGW GCC. The two compiler runtimes are not mixed.

## Provenance

The `src/OSspecific/MSwindows` implementation was adapted from
[blueCFD-Core-12](https://github.com/blueCFD/OpenFOAM-dev/tree/cdafd0c844875c0a8504fc254ab35372c568a1e4/src/OSspecific/MSwindows),
commit `cdafd0c844875c0a8504fc254ab35372c568a1e4`. Original OpenFOAM,
Symscape, and blueCAPE copyright and GPL notices are retained. The file
monitor uses the current upstream stat-based implementation.

OpenFOAM source and changes are GPL-3.0-or-later; see `COPYING`.
