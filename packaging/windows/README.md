# OpenFOAM-dev for Windows x64

This port builds Windows PE executables and DLLs with MinGW-w64 UCRT.
MSYS2 supplies the compiler and build tools. WSL, a Linux kernel, Docker,
and the MSYS runtime are not used by the packaged solver executables.

The initial package targets **double precision, 32-bit labels, serial CFD**:
`blockMesh`, `checkMesh`, `icoFoam`, and `foamDictionary`. It is not a complete
replacement for the upstream distribution. MPI, ParaView, runtime compilation,
and the remaining solver modules are not included or validated.

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
