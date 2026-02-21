@echo off
setlocal
cd /d "%~dp0.."
set "EXE=build\windows\x64\runner\Release\altyazi_editoru.exe"
if not exist "%EXE%" (
	echo [error] Release EXE not found: %EXE%
	echo [hint] Run task: Build Windows Release (stable)
	exit /b 1
)
start "" "%EXE%"
exit /b 0
