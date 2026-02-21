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
if not defined VSDEVCMD set "VSDEVCMD=C:\Program Files\Microsoft Visual Studio\18\Community\Common7\Tools\VsDevCmd.bat"
if not exist "%VSDEVCMD%" (
	echo [error] VsDevCmd.bat not found.
	exit /b 1
)

call "%VSDEVCMD%" -arch=x64 -host_arch=x64 >nul
if errorlevel 1 (
	echo [error] Failed to initialize VS environment.
	exit /b 1
)

cd /d "%~dp0.."

if not defined FLUTTER_ROOT (
	for /f "delims=" %%i in ('where flutter.bat 2^>nul') do (
		if not defined FLUTTER_EXE set "FLUTTER_EXE=%%i"
	)
	if defined FLUTTER_EXE (
		for %%i in ("!FLUTTER_EXE!\..\..") do set "FLUTTER_ROOT=%%~fi"
	)
)
if not defined FLUTTER_ROOT set "FLUTTER_ROOT=C:\Src\flutter"

if not exist "windows\flutter\ephemeral\generated_config.cmake" (
	call flutter pub get
)

set "BUILD_DIR=build\windows\x64-manual-debug"
if "%CLEAN_BUILD%"=="1" (
	if exist "%BUILD_DIR%" rmdir /s /q "%BUILD_DIR%"
)

set "CL_PATH="
for /f "delims=" %%i in ('where cl.exe 2^>nul') do (
	if not defined CL_PATH set "CL_PATH=%%i"
)
if not defined CL_PATH (
	echo [error] cl.exe not found in PATH.
	exit /b 1
)

cmake -S windows -B "%BUILD_DIR%" -G "NMake Makefiles" -DCMAKE_BUILD_TYPE=Debug -DCMAKE_C_COMPILER="%CL_PATH%" -DCMAKE_CXX_COMPILER="%CL_PATH%" -DFLUTTER_TARGET_PLATFORM=windows-x64
if errorlevel 1 (
	echo [error] CMake configure failed.
	exit /b 1
)

cmake --build "%BUILD_DIR%" --config Debug
if errorlevel 1 (
	echo [error] Debug build failed.
	exit /b 1
)

cmake --install "%BUILD_DIR%" --config Debug
if errorlevel 1 (
	echo [error] Debug install step failed.
	exit /b 1
)

set "EXE=%BUILD_DIR%\runner\altyazi_editoru.exe"
if not exist "%EXE%" set "EXE=%BUILD_DIR%\runner\Debug\altyazi_editoru.exe"
if not exist "%EXE%" (
	echo [error] Debug executable not found.
	exit /b 1
)

for %%i in ("%EXE%") do (
	set "EXE_DIR=%%~dpi"
	set "EXE_NAME=%%~nxi"
)
start "" /D "%EXE_DIR%" "%EXE_NAME%"
echo [ok] Debug app launched: %EXE%
exit /b 0
