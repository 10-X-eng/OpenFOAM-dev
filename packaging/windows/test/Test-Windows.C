// SPDX-License-Identifier: GPL-3.0-or-later
#include "fileName.H"
#include "Hash.H"
#include "int64.H"
#include "scalar.H"
#include "OSspecific.H"
#include <iostream>
#include <cstdint>

int main()
{
    using namespace Foam;
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
    std::cout << "PASS: Windows paths, LLP64 integers/pointers, and Bessel functions\n";
    return 0;
}
