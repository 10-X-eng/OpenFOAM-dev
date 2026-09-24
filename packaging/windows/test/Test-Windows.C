// SPDX-License-Identifier: GPL-3.0-or-later
#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include "fileName.H"
#include "Hash.H"
#include "int64.H"
#include "scalar.H"
#include "OSspecific.H"
#include "Pstream.H"
#include "PstreamReduceOps.H"
#include <iostream>
#include <cstdint>

int main(int argc, char** argv)
{
    using namespace Foam;
    if (argc > 1 && std::string(argv[1]) == "--libraries")
    {
        // Both upstream frameworks must load into one process on Windows.
        void* legacy = dlOpen("liblagrangian.so", true);
        void* modern = dlOpen("libLagrangian.so", true);
        if (!legacy || !modern || legacy == modern) return 10;
        void* legacyObjects = dlOpen("liblagrangianFunctionObjects.so", true);
        void* modernObjects = dlOpen("libLagrangianFunctionObjects.so", true);
        if (!legacyObjects || !modernObjects || legacyObjects == modernObjects) return 11;
        std::cout << "PASS: legacy and modern Lagrangian DLLs coexist\n";
        return 0;
    }
    const bool parallel = argc > 1 && std::string(argv[1]) == "--mpi";
    if (parallel)
    {
        UPstream::init(argc, argv, false);
        label sum = UPstream::myProcNo() + 1;
        reduce(sum, sumOp());
        const label n = UPstream::nProcs();
        if (n < 2 || sum != n*(n + 1)/2) UPstream::abort();
        if (UPstream::master()) std::cout << "PASS: native MPI reduction on " << n << " ranks\n";
        UPstream::exit(0);
    }
    if (!fileName("C:\\case\\system").isAbsolute()) return 1;
    if (fileName("C:case").isAbsolute()) return 2;
    if (fileName("relative/case").isAbsolute()) return 3;
    if (!cwd().isAbsolute()) return 4;
    if (mag(int64_t(-4294967296LL)) != int64_t(4294967296LL)) return 5;
    const void* low = reinterpret_cast<void*>(std::uintptr_t(1));
    const void* high = reinterpret_cast<void*>(std::uintptr_t(0x100000001ULL));
    if (Hash<void*>()(low) == Hash<void*>()(high)) return 6;
    if (std::abs(Foam::j0(scalar(0)) - 1) > 1e-12) return 7;
    if (std::abs(Foam::jn(1, scalar(1)) - 0.4400505857449335) > 1e-12) return 8;
    if (!GetModuleHandleW(L"libscotchDecomp.dll")
        || !GetModuleHandleW(L"libgenericFvFields.dll")) return 12;
    std::cout << "PASS: Windows paths, LLP64 integers/pointers, and Bessel functions\n";
    std::cout << "PASS: registration-only DLL imports retained\n";
    return 0;
}
