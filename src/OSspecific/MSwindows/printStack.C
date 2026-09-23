// SPDX-License-Identifier: GPL-3.0-or-later
#include "error.H"
#include "Ostream.H"
#include <sstream>
#undef DebugInfo
#include <windows.h>
namespace Foam {
void error::safePrintStack(std::ostream& os)
{
    void* frames[64];
    const USHORT count = CaptureStackBackTrace(1, 64, frames, nullptr);
    for (USHORT i = 0; i < count; ++i)
    {
        os << '#' << i << " " << frames[i] << '\n';
    }
}
void error::printStack(Ostream& os)
{
    std::ostringstream trace;
    safePrintStack(trace);
    os << trace.str().c_str();
}
}
