@echo off
setlocal
setlocal EnableDelayedExpansion
set "VSWHERE=C:\Program Files (x86)\Microsoft Visual Studio\Installer\vswhere.exe"
set "VSDEVCMD="
if exist "%VSWHERE%" (
	for /f "usebackq delims=" %%i in (`"%VSWHERE%" -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath`) do set "VSINSTALL=%%i"
	if defined VSINSTALL set "VSDEVCMD=!VSINSTALL!\Common7\Tools\VsDevCmd.bat"
)

if not defined VSDEVCMD set "VSDEVCMD=C:\Program Files\Microsoft Visual Studio\2022\Community\Common7\Tools\VsDevCmd.bat"
if not exist "%VSDEVCMD%" if exist "C:\Program Files\Microsoft Visual Studio\18\Community\Common7\Tools\VsDevCmd.bat" set "VSDEVCMD=C:\Program Files\Microsoft Visual Studio\18\Community\Common7\Tools\VsDevCmd.bat"
if not exist "%VSDEVCMD%" (
	echo [error] VsDevCmd.bat not found. Install Visual Studio with Desktop development with C++.
	exit /b 1
)

call "%VSDEVCMD%" -arch=x64 -host_arch=x64 >nul
if errorlevel 1 (
	echo [error] Failed to initialize VS developer environment from: %VSDEVCMD%
	exit /b 1
)

rem Workaround: Some VS/MSBuild setups resolve UCRT libs under
rem   C:\Program Files\Windows Kits\10\Lib
rem which may not exist (SDK is commonly under Program Files (x86)).
rem Forcing these env vars makes CMake's MSBuild-based compiler-id step find ucrtd.lib.
if defined WindowsSdkDir (
	set "UCRTContentRoot=%WindowsSdkDir%"
	set "UniversalCRTSdkDir=%WindowsSdkDir%"
)

set "KITS_LIB_ROOT=C:\Program Files (x86)\Windows Kits\10\Lib"
set "SDK_VER="
if exist "%KITS_LIB_ROOT%" (
	for /f "delims=" %%v in ('dir /b /ad "%KITS_LIB_ROOT%\10.*" 2^>nul ^| sort /r') do (
		if not defined SDK_VER set "SDK_VER=%%v"
	)
)

if defined SDK_VER (
	set "SDK_UCRT_LIB=%KITS_LIB_ROOT%\!SDK_VER!\ucrt\x64"
	set "SDK_UM_LIB=%KITS_LIB_ROOT%\!SDK_VER!\um\x64"
	if exist "!SDK_UCRT_LIB!\ucrtd.lib" set "LIB=!SDK_UCRT_LIB!;!SDK_UM_LIB!;%LIB%"
)

where cl.exe >nul 2>nul
if errorlevel 1 (
	echo [error] cl.exe not found after VsDevCmd initialization.
	exit /b 1
)

rem Some setups can end up with an incomplete windows\flutter\ephemeral\cpp_client_wrapper
rem (missing *.cc and headers). This breaks native builds.
rem Restore it from the local Flutter engine cache if needed.
set "CPP_WRAPPER_ROOT=windows\flutter\ephemeral\cpp_client_wrapper"
set "CPP_WRAPPER_SENTINEL=%CPP_WRAPPER_ROOT%\core_implementations.cc"
set "CPP_WRAPPER_HEADER_SENTINEL=%CPP_WRAPPER_ROOT%\include\flutter\flutter_engine.h"

if not exist "%CPP_WRAPPER_SENTINEL%" (
	set "NEED_CPP_WRAPPER_RESTORE=1"
) else if not exist "%CPP_WRAPPER_HEADER_SENTINEL%" (
	set "NEED_CPP_WRAPPER_RESTORE=1"
) else (
	set "NEED_CPP_WRAPPER_RESTORE=0"
)

if "%NEED_CPP_WRAPPER_RESTORE%"=="1" (
	set "FLUTTER_EXE="
	for /f "delims=" %%i in ('where flutter.bat 2^>nul') do (
		if not defined FLUTTER_EXE set "FLUTTER_EXE=%%i"
	)
	if not defined FLUTTER_EXE (
		for /f "delims=" %%i in ('where flutter 2^>nul') do (
			if not defined FLUTTER_EXE set "FLUTTER_EXE=%%i"
		)
	)
	if defined FLUTTER_EXE (
		for %%i in ("%FLUTTER_EXE%\..\..") do set "FLUTTER_ROOT=%%~fi"
	)
	if not defined FLUTTER_ROOT if exist "C:\Src\flutter\bin\flutter.bat" set "FLUTTER_ROOT=C:\Src\flutter"

	if not defined FLUTTER_ROOT (
		echo [warn] FLUTTER_ROOT not detected; skipping cpp_client_wrapper restore.
	) else (
		set "ENGINE_CPP_WRAPPER=%FLUTTER_ROOT%\bin\cache\artifacts\engine\windows-x64\cpp_client_wrapper"
		if exist "%ENGINE_CPP_WRAPPER%\core_implementations.cc" (
			echo [info] Restoring windows\\flutter\\ephemeral\\cpp_client_wrapper from Flutter engine cache...
			if not exist "%CPP_WRAPPER_ROOT%" mkdir "%CPP_WRAPPER_ROOT%" >nul 2>nul
			robocopy "%ENGINE_CPP_WRAPPER%" "%CPP_WRAPPER_ROOT%" /E /NFL /NDL /NJH /NJS /NP >nul
		) else (
			echo [warn] Engine cpp_client_wrapper not found at: %ENGINE_CPP_WRAPPER%
		)
	)
)

set "CMAKE_GENERATOR="
set "CMAKE_C_COMPILER="
set "CMAKE_CXX_COMPILER="
set "CC=cl.exe"
set "CXX=cl.exe"
cd /d "%~dp0.."

rem Avoid LNK1168 (cannot overwrite exe while it is running)
taskkill /im altyazi_editoru.exe /f >nul 2>nul

if exist "build\windows\x64\CMakeCache.txt" del /f /q "build\windows\x64\CMakeCache.txt" >nul 2>nul
if exist "build\windows\x64\cmake_install.cmake" del /f /q "build\windows\x64\cmake_install.cmake" >nul 2>nul
if exist "build\windows\x64\CMakeFiles" rmdir /s /q "build\windows\x64\CMakeFiles" >nul 2>nul
call flutter run -d windows %*
exit /b %errorlevel%
