; SPDX-License-Identifier: GPL-3.0-or-later
Unicode True
!include "MUI2.nsh"
!include "LogicLib.nsh"
!include "x64.nsh"

Name "OpenFOAM-dev for Windows"
OutFile "${OUTPUT_EXE}"
InstallDir "$LOCALAPPDATA\Programs\OpenFOAM-dev"
InstallDirRegKey HKCU "Software\OpenFOAM-native" "InstallDir"
RequestExecutionLevel user
SetCompressor /SOLID lzma
ShowInstDetails show
ShowUninstDetails show

!define MUI_ABORTWARNING
!insertmacro MUI_PAGE_WELCOME
!insertmacro MUI_PAGE_LICENSE "${PACKAGE_DIR}\COPYING"
!insertmacro MUI_PAGE_DIRECTORY
!insertmacro MUI_PAGE_INSTFILES
!insertmacro MUI_PAGE_FINISH
!insertmacro MUI_UNPAGE_CONFIRM
!insertmacro MUI_UNPAGE_INSTFILES
!insertmacro MUI_LANGUAGE "English"

Function .onInit
    ${IfNot} ${RunningX64}
        MessageBox MB_ICONSTOP "OpenFOAM requires 64-bit Windows."
        Abort
    ${EndIf}
    SetRegView 64
    SetShellVarContext current
FunctionEnd

Section "OpenFOAM"
    ; MPI is bundled app-locally; installing does not modify system services.
    SetOutPath "$INSTDIR"
    File /r "${PACKAGE_DIR}\*"
    SetOutPath "$INSTDIR\source"
    File "${SOURCE_ARCHIVE}"
    WriteUninstaller "$INSTDIR\Uninstall.exe"
    CreateDirectory "$SMPROGRAMS\OpenFOAM-dev"
    SetOutPath "$DOCUMENTS"
    CreateShortcut "$SMPROGRAMS\OpenFOAM-dev\OpenFOAM.lnk" "$INSTDIR\OpenFOAM.exe"
    CreateShortcut "$SMPROGRAMS\OpenFOAM-dev\Uninstall.lnk" "$INSTDIR\Uninstall.exe"
    WriteRegStr HKCU "Software\OpenFOAM-native" "InstallDir" "$INSTDIR"
    WriteRegStr HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\OpenFOAM-native" "DisplayName" "OpenFOAM-dev for Windows"
    WriteRegStr HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\OpenFOAM-native" "DisplayVersion" "${REVISION}"
    WriteRegStr HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\OpenFOAM-native" "UninstallString" '$\"$INSTDIR\Uninstall.exe$\"'
    WriteRegStr HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\OpenFOAM-native" "DisplayIcon" "$INSTDIR\OpenFOAM.exe"
    WriteRegDWORD HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\OpenFOAM-native" "NoModify" 1
    WriteRegDWORD HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\OpenFOAM-native" "NoRepair" 1
SectionEnd

Section "Uninstall"
    SetRegView 64
    SetShellVarContext current
    ; Generated exact file list: leave user-added files and case workspaces alone.
    !include "${UNINSTALL_FILES}"
    Delete "$INSTDIR\source\${SOURCE_NAME}"
    RMDir "$INSTDIR\source"
    Delete "$INSTDIR\Uninstall.exe"
    RMDir "$INSTDIR"
    Delete "$SMPROGRAMS\OpenFOAM-dev\OpenFOAM.lnk"
    Delete "$SMPROGRAMS\OpenFOAM-dev\Uninstall.lnk"
    RMDir "$SMPROGRAMS\OpenFOAM-dev"
    DeleteRegKey HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\OpenFOAM-native"
    DeleteRegKey HKCU "Software\OpenFOAM-native"
SectionEnd
