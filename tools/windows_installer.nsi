; Rebuild with: makensis tools/windows_installer.nsi
Unicode true
!include "MUI2.nsh"
!include "LogicLib.nsh"
!include "x64.nsh"
!include "FileFunc.nsh"

!define PRODUCT "Converge Demo"
!define VERSION "0.1.0"
!define APP_KEY "Software\ConvergeDemo"
!define UNINSTALL_KEY "Software\Microsoft\Windows\CurrentVersion\Uninstall\ConvergeDemo"
!ifndef INPUT_DIR
  !define INPUT_DIR "../out/demo-validation/windows"
!endif
!ifndef OUTPUT_FILE
  !define OUTPUT_FILE "../out/demo-validation/Converge-demo-0.1.0-windows-x64-setup.exe"
!endif

Name "${PRODUCT} ${VERSION}"
OutFile "${OUTPUT_FILE}"
InstallDir "$LOCALAPPDATA\Programs\Converge Demo"
InstallDirRegKey HKCU "${APP_KEY}" "InstallDir"
RequestExecutionLevel user
SetCompressor /SOLID lzma
SetCompressorDictSize 32
ShowInstDetails show
ShowUninstDetails show
VIProductVersion "0.1.0.0"
VIAddVersionKey /LANG=2052 "ProductName" "${PRODUCT}"
VIAddVersionKey /LANG=2052 "FileDescription" "Converge Demo 安装程序"
VIAddVersionKey /LANG=2052 "FileVersion" "${VERSION}"
VIAddVersionKey /LANG=2052 "ProductVersion" "${VERSION}"
VIAddVersionKey /LANG=2052 "LegalCopyright" "vansheng"

!define MUI_ICON "../assets/icons/converge.ico"
!define MUI_UNICON "../assets/icons/converge.ico"
!define MUI_ABORTWARNING
!define MUI_LANGDLL_REGISTRY_ROOT HKCU
!define MUI_LANGDLL_REGISTRY_KEY "${APP_KEY}"
!define MUI_LANGDLL_REGISTRY_VALUENAME "InstallerLanguage"
!define MUI_FINISHPAGE_RUN "$INSTDIR\Converge-demo.exe"
!define MUI_FINISHPAGE_RUN_NOTCHECKED
!insertmacro MUI_PAGE_WELCOME
!insertmacro MUI_PAGE_COMPONENTS
!insertmacro MUI_PAGE_DIRECTORY
!insertmacro MUI_PAGE_INSTFILES
!insertmacro MUI_PAGE_FINISH
!insertmacro MUI_UNPAGE_CONFIRM
!insertmacro MUI_UNPAGE_INSTFILES
!insertmacro MUI_UNPAGE_FINISH
!insertmacro MUI_LANGUAGE "SimpChinese"
!insertmacro MUI_LANGUAGE "English"
!insertmacro MUI_LANGUAGE "Korean"

LangString GameSection ${LANG_SIMPCHINESE} "游戏文件（必选）"
LangString GameSection ${LANG_ENGLISH} "Game files (required)"
LangString GameSection ${LANG_KOREAN} "게임 파일 (필수)"
LangString DesktopSection ${LANG_SIMPCHINESE} "创建桌面快捷方式"
LangString DesktopSection ${LANG_ENGLISH} "Create a desktop shortcut"
LangString DesktopSection ${LANG_KOREAN} "바탕 화면 바로 가기 만들기"
LangString Unsupported ${LANG_SIMPCHINESE} "此版本需要 64 位 Windows。"
LangString Unsupported ${LANG_ENGLISH} "This version requires 64-bit Windows."
LangString Unsupported ${LANG_KOREAN} "이 버전은 64비트 Windows가 필요합니다."

Function .onInit
  SetShellVarContext current
  !insertmacro MUI_LANGDLL_DISPLAY
  ${IfNot} ${RunningX64}
    MessageBox MB_OK|MB_ICONSTOP "$(Unsupported)"
    Abort
  ${EndIf}
FunctionEnd

Section "$(GameSection)" SEC_GAME
  SectionIn RO
  SetOutPath "$INSTDIR"
  File "${INPUT_DIR}/Converge-demo.exe"
  File "${INPUT_DIR}/Converge-demo.pck"
  File "${INPUT_DIR}/README.txt"
  WriteUninstaller "$INSTDIR\Uninstall.exe"
  CreateDirectory "$SMPROGRAMS\Converge Demo"
  CreateShortcut "$SMPROGRAMS\Converge Demo\Converge Demo.lnk" "$INSTDIR\Converge-demo.exe"
  CreateShortcut "$SMPROGRAMS\Converge Demo\Uninstall.lnk" "$INSTDIR\Uninstall.exe"
  WriteRegStr HKCU "${APP_KEY}" "InstallDir" "$INSTDIR"
  WriteRegStr HKCU "${UNINSTALL_KEY}" "DisplayName" "${PRODUCT}"
  WriteRegStr HKCU "${UNINSTALL_KEY}" "DisplayVersion" "${VERSION}"
  WriteRegStr HKCU "${UNINSTALL_KEY}" "Publisher" "vansheng"
  WriteRegStr HKCU "${UNINSTALL_KEY}" "InstallLocation" "$INSTDIR"
  WriteRegStr HKCU "${UNINSTALL_KEY}" "DisplayIcon" "$INSTDIR\Converge-demo.exe,0"
  WriteRegStr HKCU "${UNINSTALL_KEY}" "UninstallString" '$\"$INSTDIR\Uninstall.exe$\"'
  WriteRegStr HKCU "${UNINSTALL_KEY}" "QuietUninstallString" '$\"$INSTDIR\Uninstall.exe$\" /S'
  WriteRegDWORD HKCU "${UNINSTALL_KEY}" "NoModify" 1
  WriteRegDWORD HKCU "${UNINSTALL_KEY}" "NoRepair" 1
  ${GetSize} "$INSTDIR" "/S=0K" $0 $1 $2
  WriteRegDWORD HKCU "${UNINSTALL_KEY}" "EstimatedSize" $0
SectionEnd

Section "$(DesktopSection)" SEC_DESKTOP
  CreateShortcut "$DESKTOP\Converge Demo.lnk" "$INSTDIR\Converge-demo.exe"
SectionEnd

Function un.onInit
  SetShellVarContext current
  !insertmacro MUI_UNGETLANGUAGE
FunctionEnd

Section "Uninstall"
  Delete "$INSTDIR\Converge-demo.exe"
  Delete "$INSTDIR\Converge-demo.pck"
  Delete "$INSTDIR\README.txt"
  Delete "$INSTDIR\Uninstall.exe"
  RMDir "$INSTDIR"
  Delete "$DESKTOP\Converge Demo.lnk"
  Delete "$SMPROGRAMS\Converge Demo\Converge Demo.lnk"
  Delete "$SMPROGRAMS\Converge Demo\Uninstall.lnk"
  RMDir "$SMPROGRAMS\Converge Demo"
  DeleteRegKey HKCU "${UNINSTALL_KEY}"
  DeleteRegKey HKCU "${APP_KEY}"
SectionEnd
