// SPDX-License-Identifier: GPL-3.0-or-later
// A unique import keeps a DLL's run-time selection registrations alive on PE.
#define FOAM_JOIN_IMPL(a, b) a##b
#define FOAM_JOIN(a, b) FOAM_JOIN_IMPL(a, b)
extern "C" __declspec(dllexport)
void FOAM_JOIN(openfoamAnchor_, FOAM_WINDOWS_LIBRARY)()
{}
