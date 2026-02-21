@echo off
setlocal EnableDelayedExpansion
set "VSWHERE=C:\Program Files (x86)\Microsoft Visual Studio\Installer\vswhere.exe"
set "VSDEVCMD="
if exist "%VSWHERE%" (
  for /f "usebackq delims=" %%i in (`"%VSWHERE%" -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath`) do set "VSINSTALL=%%i"
  if defined VSINSTALL set "VSDEVCMD=!VSINSTALL!\Common7\Tools\VsDevCmd.bat"
)
if not defined VSDEVCMD set "VSDEVCMD=C:\Program Files\Microsoft Visual Studio\18\Community\Common7\Tools\VsDevCmd.bat"
if not exist "%VSDEVCMD%" (
  echo [error] VsDevCmd.bat not found: %VSDEVCMD%
  exit /b 1
)
call "%VSDEVCMD%" -arch=x64 -host_arch=x64 >nul
if errorlevel 1 exit /b 1
echo === UniversalCRTSdkDir ===
echo %UniversalCRTSdkDir%
echo === UCRTVersion ===
echo %UCRTVersion%
echo === WindowsSDKLibVersion ===
echo %WindowsSDKLibVersion%
echo === LIB (first 500 chars) ===
set "LIB_TRUNC=%LIB:~0,500%"
echo %LIB_TRUNC%
echo === LIB contains ucrt\x64? ===
echo %LIB% | findstr /I "\\Windows Kits\\10\\Lib" >nul && (echo YES) || (echo NO)
echo %LIB% | findstr /I "\\ucrt\\x64" >nul && (echo YES) || (echo NO)
exit /b 0
