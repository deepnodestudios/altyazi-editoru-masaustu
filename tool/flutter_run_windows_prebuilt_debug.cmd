@echo off
setlocal
cd /d "%~dp0.."

set "EXE=build\windows\x64-manual-debug\runner\altyazi_editoru.exe"
if not exist "%EXE%" set "EXE=build\windows\x64-manual-debug\runner\Debug\altyazi_editoru.exe"
if not exist "%EXE%" (
	echo [error] Debug EXE not found.
	echo [hint] Run once: Run Windows Debug (Manual NMake Rebuild)
	exit /b 1
)

if not exist "build\windows\x64-manual-debug\runner\data\flutter_assets" (
	echo [error] Debug runtime bundle is missing.
	echo [hint] Run once: Run Windows Debug (Manual NMake Rebuild)
	exit /b 1
)

call flutter run -d windows --use-application-binary "%EXE%"
exit /b %errorlevel%
