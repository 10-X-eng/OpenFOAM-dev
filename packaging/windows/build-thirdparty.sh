#!/usr/bin/env bash
set -eo pipefail
source "$(dirname "$0")/environment.sh"
# Pin the matching upstream third-party source instead of tracking a moving HEAD.
revision=4b11545ee30fe1625e39b23df8b2fe916a42a198
if [ ! -d "$WM_THIRD_PARTY_DIR/.git" ]; then
    mkdir -p "$WM_THIRD_PARTY_DIR"
    git -C "$WM_THIRD_PARTY_DIR" init
    git -C "$WM_THIRD_PARTY_DIR" config core.autocrlf false
    git -C "$WM_THIRD_PARTY_DIR" config core.longpaths true
    git -C "$WM_THIRD_PARTY_DIR" fetch --depth 1 https://github.com/OpenFOAM/ThirdParty-dev.git "$revision"
    git -C "$WM_THIRD_PARTY_DIR" checkout --detach FETCH_HEAD
fi
[ "$(git -C "$WM_THIRD_PARTY_DIR" rev-parse HEAD)" = "$revision" ] || {
    echo "Unexpected ThirdParty revision; expected $revision" >&2; exit 1;
}
cd "$WM_THIRD_PARTY_DIR/Zoltan-3.90"
mkdir -p build-windows
cd build-windows
if [ ! -f Makefile ]; then
    ../configure --host=x86_64-w64-mingw32 \
        --prefix="$ZOLTAN_ARCH_PATH" --libdir="$FOAM_EXT_LIBBIN/$FOAM_MPI" \
        --enable-mpi=yes --with-mpi-compilers=no \
        --with-mpi-incdir=/ucrt64/include --with-mpi-libs=-lmsmpi \
        --disable-zoltan-cppdriver --disable-f90interface CC=gcc CXX=g++
fi
make -j "${JOBS:-8}" everything
make install
