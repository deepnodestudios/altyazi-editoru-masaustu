@echo off
setlocal
setlocal EnableDelayedExpansion
set "CLEAN_BUILD=0"
if /I "%~1"=="--clean" set "CLEAN_BUILD=1"
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

set "CMAKE_GENERATOR=NMake Makefiles"
set "CMAKE_C_COMPILER=cl.exe"
set "CMAKE_CXX_COMPILER=cl.exe"
cd /d "%~dp0.."
if "%CLEAN_BUILD%"=="1" (
	if exist "build\windows\x64\CMakeCache.txt" del /f /q "build\windows\x64\CMakeCache.txt" >nul 2>nul
	if exist "build\windows\x64\cmake_install.cmake" del /f /q "build\windows\x64\cmake_install.cmake" >nul 2>nul
	if exist "build\windows\x64\CMakeFiles" rmdir /s /q "build\windows\x64\CMakeFiles" >nul 2>nul
)
call flutter pub get
echo [pubget] exit code %errorlevel%
echo [build] starting flutter build windows...
call flutter build windows --release --split-debug-info=build/symbols/windows --obfuscate
echo [build] flutter build finished with exit code %errorlevel%
exit /b %errorlevel%
