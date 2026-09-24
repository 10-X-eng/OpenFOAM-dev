#!/usr/bin/env bash
set -eo pipefail
source "$(dirname "$0")/environment.sh"
cd "$WM_PROJECT_DIR"
mkdir -p "$FOAM_APPBIN" "$FOAM_LIBBIN"
rm -f "$FOAM_APPBIN/../.full-build-revision"
# Remove only the superseded native filenames. The checkout and platforms
# directory are case-sensitive, so legacy liblagrangian remains untouched.
rm -f "$FOAM_LIBBIN/libLagrangian.dll" "$FOAM_LIBBIN/libLagrangian.dll.a" \
    "$FOAM_LIBBIN/libLagrangianFunctionObjects.dll" "$FOAM_LIBBIN/libLagrangianFunctionObjects.dll.a"
bash packaging/windows/build-thirdparty.sh
mkdir -p "$WM_PROJECT_DIR/platforms/windows-include"
resource="$WM_PROJECT_DIR/platforms/windows-include/application.o"
if [ ! -f "$resource" ] || [ packaging/windows/application.rc -nt "$resource" ] \
    || [ packaging/windows/application.manifest -nt "$resource" ]; then
    windres -I packaging/windows packaging/windows/application.rc "$resource"
fi
# Use the architecture-independent Flex C++ header without adding MSYS system
# headers to a native Windows compilation.
cmp -s /usr/include/FlexLexer.h "$WM_PROJECT_DIR/platforms/windows-include/FlexLexer.h" ||
    cp /usr/include/FlexLexer.h "$WM_PROJECT_DIR/platforms/windows-include/"
make -C wmake/src cc=/usr/bin/gcc cFLAGS=-O2
wmakeLnInclude src/OpenFOAM
wmakeLnInclude src/OSspecific/MSwindows
wmakeLnInclude src/polyTopoChange
if ! wmakePrintBuild -check; then touch src/OpenFOAM/global/global.Cver; fi
# Build the complete upstream library, solver/module and utility lists.
# AllwmakeParseArguments enables stop-on-error in each recursive build.
mkdir -p "$FOAM_LIBBIN/$FOAM_MPI" "$FOAM_EXT_LIBBIN/$FOAM_MPI"
wmakeLnInclude src/Pstream/mpi
wmake -j "${JOBS:-8}" -all libso src
wmake -j "${JOBS:-8}" -all applications
wmake -j "${JOBS:-8}" packaging/windows/test
g++ -std=c++17 -O2 -municode -static -static-libgcc -static-libstdc++ \
    packaging/windows/launcher.cpp -o "$FOAM_APPBIN/../OpenFOAM.exe" \
    "$WM_PROJECT_DIR/platforms/windows-include/application.o" \
    -lshell32 -lole32 -luuid
git rev-parse HEAD > "$FOAM_APPBIN/../.full-build-revision"
