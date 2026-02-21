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
	echo [error] VsDevCmd.bat not found. C++ build tools are required.
	exit /b 1
)

call "%VSDEVCMD%" -arch=x64 -host_arch=x64 >nul
if errorlevel 1 (
	echo [error] Failed to initialize VS developer environment.
	exit /b 1
)

cd /d "%~dp0.."

for /f "delims=" %%i in ('where cl.exe 2^>nul') do if not defined CL_EXE set "CL_EXE=%%i"
if not defined CL_EXE (
	echo [error] cl.exe not found after VsDevCmd.
	exit /b 1
)

rem Force Flutter to configure with NMake generator (avoids VS generator/MSBuild ucrtd.lib issue)
set "CMAKE_GENERATOR=NMake Makefiles"
set "CMAKE_C_COMPILER=%CL_EXE%"
set "CMAKE_CXX_COMPILER=%CL_EXE%"
set "CC=cl.exe"
set "CXX=cl.exe"

call flutter run -d windows
exit /b %errorlevel%
