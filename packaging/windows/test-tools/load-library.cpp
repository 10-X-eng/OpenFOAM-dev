#include <windows.h>
#include <cstdio>
int wmain(int argc, wchar_t** argv) {
    SetErrorMode(SEM_FAILCRITICALERRORS | SEM_NOGPFAULTERRORBOX);
    if (argc != 2) return 2;
    if (!LoadLibraryExW(argv[1], nullptr, LOAD_WITH_ALTERED_SEARCH_PATH)) {
        std::fprintf(stderr, "Windows DLL load failed: %lu\n", GetLastError());
        return 1;
    }
    return 0;
}
