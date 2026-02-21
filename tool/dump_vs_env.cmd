@echo off
setlocal EnableDelayedExpansion
set "VSWHERE=C:\Program Files (x86)\Microsoft Visual Studio\Installer\vswhere.exe"
set "VSDEVCMD="
if exist "%VSWHERE%" (
	for /f "usebackq delims=" %%i in (`"%VSWHERE%" -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath`) do set "VSINSTALL=%%i"
	if defined VSINSTALL set "VSDEVCMD=!VSINSTALL!\Common7\Tools\VsDevCmd.bat"
)

if not defined VSDEVCMD set "VSDEVCMD=C:\Program Files\Microsoft Visual Studio\2022\Community\Common7\Tools\VsDevCmd.bat"
if not exist "%VSDEVCMD%" (
	echo [error] VsDevCmd.bat not found. Install Visual Studio 2022 with Desktop development with C++ workload.
	exit /b 1
)

call "%VSDEVCMD%" -arch=x64 -host_arch=x64 >nul
if errorlevel 1 (
	echo [error] Failed to initialize VS developer environment from: %VSDEVCMD%
	exit /b 1
)
echo UniversalCRTSdkDir=%UniversalCRTSdkDir%
echo UCRTVersion=%UCRTVersion%
echo WindowsSdkDir=%WindowsSdkDir%
echo WindowsSDKLibVersion=%WindowsSDKLibVersion%
echo VCToolsInstallDir=%VCToolsInstallDir%
