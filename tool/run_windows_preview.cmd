@echo off
setlocal
cd /d "%~dp0.."
set "EXE=build\windows\x64-manual\runner\altyazi_editoru.exe"
set "BUNDLE_DATA=build\windows\x64-manual\runner\data\flutter_assets"
if not exist "%EXE%" (
	echo [error] Preview EXE not found: %EXE%
	echo [hint] Build once with: Run Windows (Manual NMake Stable)
	exit /b 1
)
if not exist "%BUNDLE_DATA%" (
	where cmake >nul 2>nul
	if not errorlevel 1 cmake --install build\windows\x64-manual --config Release >nul 2>nul
)
if not exist "%BUNDLE_DATA%" (
	echo [error] Runtime bundle is missing (data/flutter_assets).
	echo [hint] Run once: Run Windows (Manual NMake Stable)
	exit /b 1
)
for %%i in ("%EXE%") do (
	set "EXE_DIR=%%~dpi"
	set "EXE_NAME=%%~nxi"
)
start "" /D "%EXE_DIR%" "%EXE_NAME%"
timeout /t 1 >nul
powershell -NoProfile -Command "$p = Get-Process -Name 'altyazi_editoru' -ErrorAction SilentlyContinue | Sort-Object StartTime -Descending | Select-Object -First 1; if ($p) { $ws = New-Object -ComObject WScript.Shell; $null = $ws.AppActivate($p.Id) }" >nul 2>nul
echo [ok] Preview launched: %EXE%
exit /b 0
