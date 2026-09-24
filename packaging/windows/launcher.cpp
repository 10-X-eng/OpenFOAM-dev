// SPDX-License-Identifier: GPL-3.0-or-later
// Native launcher: configure only the child environment; retain command arguments.
#ifndef UNICODE
#define UNICODE
#endif
#ifndef _UNICODE
#define _UNICODE
#endif
#define NOMINMAX
#include <windows.h>
#include <shlobj.h>
#include <filesystem>
#include <iostream>
#include <string>
#include <vector>

static std::wstring env(const wchar_t* name)
{
    DWORD n = GetEnvironmentVariableW(name, nullptr, 0);
    if (!n) return {};
    std::wstring value(n, L'\0');
    value.resize(GetEnvironmentVariableW(name, value.data(), n));
    return value;
}

// CommandLineToArgvW/CRT quoting, including trailing backslashes and empty args.
static std::wstring quote(const std::wstring& arg)
{
    std::wstring out = L"\"";
    size_t slashes = 0;
    for (wchar_t c : arg)
    {
        if (c == L'\\') { ++slashes; continue; }
        out.append(c == L'"' ? slashes * 2 + 1 : slashes, L'\\');
        slashes = 0;
        out += c;
    }
    out.append(slashes * 2, L'\\');
    return out + L'"';
}

int wmain(int argc, wchar_t** argv)
{
    try
    {
        std::vector<wchar_t> module(32768);
        DWORD n = GetModuleFileNameW(nullptr, module.data(), DWORD(module.size()));
        if (!n || n == module.size()) throw std::runtime_error("Cannot locate installation");
        const auto root = std::filesystem::path(module.data()).parent_path();
        auto set = [](const wchar_t* key, const std::wstring& value)
        {
            if (!SetEnvironmentVariableW(key, value.c_str()))
                throw std::runtime_error("Cannot set OpenFOAM environment");
        };
        set(L"WM_PROJECT", L"OpenFOAM");
        set(L"WM_PROJECT_VERSION", L"dev");
        set(L"WM_PROJECT_DIR", root.wstring());
        set(L"FOAM_ETC", (root / L"etc").wstring());
        set(L"FOAM_TUTORIALS", (root / L"tutorials").wstring());
        set(L"FOAM_APPBIN", (root / L"bin").wstring());
        set(L"FOAM_LIBBIN", (root / L"bin").wstring());
        if (env(L"MPI_BUFFER_SIZE").empty()) set(L"MPI_BUFFER_SIZE", L"20000000");
        std::wstring path = (root / L"bin").wstring() + L";";
        auto mpi = env(L"MSMPI_BIN");
        if (mpi.empty()) mpi = env(L"ProgramFiles") + L"\\Microsoft MPI\\Bin";
        set(L"PATH", path + mpi + L";" + env(L"PATH"));
        auto run = env(L"FOAM_RUN");
        if (run.empty())
        {
            PWSTR documents = nullptr;
            if (FAILED(SHGetKnownFolderPath(FOLDERID_Documents, 0, nullptr, &documents)))
                throw std::runtime_error("Cannot locate Documents directory");
            run = (std::filesystem::path(documents) / L"OpenFOAM" / L"run").wstring();
            CoTaskMemFree(documents);
        }
        set(L"FOAM_RUN", run);
        set(L"WM_PROJECT_USER_DIR", std::filesystem::path(run).parent_path().wstring());
        std::wstring command;
        if (argc > 1)
        {
            // Resolve bundled tools first, including when a case directory
            // contains a file with the same name as an OpenFOAM command.
            std::filesystem::path program(argv[1]);
            if (!program.has_parent_path())
            {
                auto candidate = root / L"bin" / program;
                if (!candidate.has_extension()) candidate += L".exe";
                if (std::filesystem::is_regular_file(candidate)) program = candidate;
            }
            for (int i = 1; i < argc; ++i)
            {
                if (i > 1) command += L' ';
                command += quote(i == 1 ? program.wstring() : std::wstring(argv[i]));
            }
        }
        else
        {
            std::filesystem::create_directories(run);
            if (!SetCurrentDirectoryW(run.c_str()))
                throw std::runtime_error("Cannot open case workspace");
            std::wcout << L"OpenFOAM-dev for Windows x64\n"
                << L"Native solvers, utilities and Microsoft MPI\n"
                << L"Cases: " << run << L"\n"
                << L"Tutorials: " << (root / L"tutorials").wstring() << L"\n\n";
            command = quote(env(L"ComSpec")) + L" /D /K";
        }
        STARTUPINFOW si{};
        si.cb = sizeof(si);
        PROCESS_INFORMATION pi{};
        if (!CreateProcessW(nullptr, command.data(), nullptr, nullptr, TRUE, 0,
                            nullptr, nullptr, &si, &pi))
        {
            std::wcerr << L"Cannot start command (Windows error " << GetLastError() << L").\n";
            return 1;
        }
        CloseHandle(pi.hThread);
        WaitForSingleObject(pi.hProcess, INFINITE);
        DWORD status = 1;
        GetExitCodeProcess(pi.hProcess, &status);
        CloseHandle(pi.hProcess);
        return static_cast<int>(status);
    }
    catch (const std::exception& e)
    {
        std::cerr << "OpenFOAM: " << e.what() << '\n';
        return 1;
    }
}
