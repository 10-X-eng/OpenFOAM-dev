@echo off
setlocal
set "WM_PROJECT=OpenFOAM"
set "WM_PROJECT_VERSION=dev"
set "WM_PROJECT_DIR=%~dp0"
set "FOAM_ETC=%~dp0etc"
set "FOAM_TUTORIALS=%~dp0tutorials"
set "FOAM_LIBBIN=%~dp0bin"
set "FOAM_APPBIN=%~dp0bin"
set "WM_PROJECT_USER_DIR=%~dp0run"
set "FOAM_RUN=%~dp0run"
set "PATH=%~dp0bin;%PATH%"
if not exist "%FOAM_RUN%" mkdir "%FOAM_RUN%"
cd /d "%FOAM_RUN%"
if not "%~1"=="" goto run
echo OpenFOAM-dev native Windows x64 - serial build
echo Commands: blockMesh, checkMesh, icoFoam, foamDictionary
cmd /k
exit /b
:run
%*
exit /b %errorlevel%
