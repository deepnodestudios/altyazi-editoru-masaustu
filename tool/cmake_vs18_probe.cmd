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
  echo [error] VsDevCmd.bat not found.
  exit /b 1
)
call "%VSDEVCMD%" -arch=x64 -host_arch=x64 >nul
if errorlevel 1 (
  echo [error] VsDevCmd failed.
  exit /b 1
)
cd /d "%~dp0.."
echo === key env ===
echo WindowsSdkDir=%WindowsSdkDir%
echo UniversalCRTSdkDir=%UniversalCRTSdkDir%
echo UCRTVersion=%UCRTVersion%
echo WindowsSDKLibVersion=%WindowsSDKLibVersion%
echo VCToolsInstallDir=%VCToolsInstallDir%
echo === where cmake ===
where cmake
echo === cmake version ===
cmake --version
echo === configure (VS 18 generator) ===
cmake -S windows -B build\windows\x64_probe -G "Visual Studio 18 2026" -A x64 -DFLUTTER_TARGET_PLATFORM=windows-x64
exit /b %errorlevel%
