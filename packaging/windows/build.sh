#!/usr/bin/env bash
set -eo pipefail
source "$(dirname "$0")/environment.sh"
cd "$WM_PROJECT_DIR"
mkdir -p "$FOAM_APPBIN" "$FOAM_LIBBIN"
mkdir -p "$WM_PROJECT_DIR/platforms/windows-include"
# Use the architecture-independent Flex C++ header without adding MSYS system
# headers to a native Windows compilation.
cp /usr/include/FlexLexer.h "$WM_PROJECT_DIR/platforms/windows-include/"
make -C wmake/src cc=/usr/bin/gcc cFLAGS=-O2
wmakeLnInclude src/OpenFOAM
wmakeLnInclude src/OSspecific/MSwindows
wmakeLnInclude src/polyTopoChange
if ! wmakePrintBuild -check; then touch src/OpenFOAM/global/global.Cver; fi
wmake -j "${JOBS:-8}" libo src/OSspecific/MSwindows
wmake -j "${JOBS:-8}" libso src/OpenFOAM
wmake -j "${JOBS:-8}" packaging/windows/test

# A useful serial CFD toolchain, with dependencies ordered explicitly. Other
# modules can be added only after they have been built and tested on Windows.
for library in \
    fileFormats surfMesh triSurface meshTools finiteVolume \
    tracking lagrangian/basic sampling \
    generic/genericPatches meshCheck mesh/extrudeModel polyTopoChange \
    mesh/blockMesh
do
    wmake -j "${JOBS:-8}" libso "src/$library"
done
for application in \
    utilities/miscellaneous/foamDictionary \
    utilities/mesh/generation/blockMesh \
    utilities/mesh/manipulation/checkMesh \
    legacy/incompressible/icoFoam
do
    wmake -j "${JOBS:-8}" "applications/$application"
done
