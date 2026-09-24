// SPDX-License-Identifier: GPL-3.0-or-later
// Keep Win32 macros such as ERROR separate from the OpenFOAM headers.
#define WIN32_LEAN_AND_MEAN
#include <windows.h>

bool windowsLibrariesRetained()
{
    return GetModuleHandleW(L"libscotchDecomp.dll")
        && GetModuleHandleW(L"libgenericFvFields.dll");
}
