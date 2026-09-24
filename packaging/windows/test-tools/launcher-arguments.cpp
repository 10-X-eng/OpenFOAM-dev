#include <windows.h>
#include <string>
#include <iostream>
int wmain(int argc, wchar_t** argv) {
    if (argc != 6) return 91;
    if (std::wstring(argv[1]) != L"with spaces" || std::wstring(argv[2]) != L"" || std::wstring(argv[3]) != L"quote\"and\\tail\\") return 92;
    wchar_t cwd[32768], root[32768];
    if (!GetCurrentDirectoryW(32768, cwd) || !GetEnvironmentVariableW(L"WM_PROJECT_DIR", root, 32768)) return 93;
    if (_wcsicmp(cwd, argv[4]) || _wcsicmp(root, argv[5])) return 94;
    std::cout << "PASS: quoted arguments, empty argument, working directory and child environment\n";
    return 37;
}
