@echo off
setlocal
if not defined FOAM_BASH set "FOAM_BASH=C:\msys64\usr\bin\bash.exe"
if not exist "%FOAM_BASH%" (
    echo Native code compilation requires MSYS2. Set FOAM_BASH to its bash.exe. 1>&2
    exit /b 1
)
"%FOAM_BASH%" "%~dp0..\packaging\windows\wmake-native.sh" %*
exit /b %errorlevel%
