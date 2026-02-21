@echo off
setlocal
cd /d "%~dp0.."
set "EXE=build\windows\x64-manual-debug\runner\altyazi_editoru.exe"
if not exist "%EXE%" set "EXE=build\windows\x64-manual-debug\runner\Debug\altyazi_editoru.exe"
set "BUNDLE_DATA=build\windows\x64-manual-debug\runner\data\flutter_assets"
if not exist "%EXE%" (
	echo [error] Debug EXE not found: build\windows\x64-manual-debug\runner\altyazi_editoru.exe
	echo [hint] Run once: Run Windows Debug (Manual NMake Rebuild)
	exit /b 1
)
if not exist "%BUNDLE_DATA%" (
	where cmake >nul 2>nul
	if not errorlevel 1 cmake --install build\windows\x64-manual-debug --config Debug >nul 2>nul
)
if not exist "%BUNDLE_DATA%" (
	echo [error] Debug runtime bundle is missing (data/flutter_assets).
	echo [hint] Run once: Run Windows Debug (Manual NMake Rebuild)
	exit /b 1
)
for %%i in ("%EXE%") do (
	set "EXE_DIR=%%~dpi"
	set "EXE_NAME=%%~nxi"
)
start "" /D "%EXE_DIR%" "%EXE_NAME%"
timeout /t 1 >nul
powershell -NoProfile -Command "$p = Get-Process -Name 'altyazi_editoru' -ErrorAction SilentlyContinue | Sort-Object StartTime -Descending | Select-Object -First 1; if ($p) { $ws = New-Object -ComObject WScript.Shell; $null = $ws.AppActivate($p.Id) }" >nul 2>nul
echo [ok] Debug preview launched: %EXE%
exit /b 0
