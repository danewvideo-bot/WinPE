@echo off
setlocal EnableExtensions EnableDelayedExpansion

cd /d "%~dp0"
set "ROOT=%CD%"
set "LOGDIR=%ROOT%\logs"
if not exist "%LOGDIR%" mkdir "%LOGDIR%" >nul 2>nul

for /f %%I in ('powershell -NoProfile -Command "Get-Date -Format yyyyMMdd_HHmmss"') do set "TS=%%I"
set "LOG=%LOGDIR%\build-all_%TS%.log"

echo [DBG] pwd = %ROOT%
echo [DBG] LOGDIR=%LOGDIR%
echo [DBG] LOG=%LOG%
echo probe>%LOGDIR%\_probe.txt
echo [DBG] probe write errorlevel=!errorlevel!
del /q "%LOGDIR%\_probe.txt" >nul 2>nul

echo [INFO] Log file: %LOG%

rem ---- locate pwsh
where pwsh >nul 2>nul
if %errorlevel%==0 (
  set "PWSH=pwsh"
) else (
  set "PWSH=powershell"
)

rem ---- admin check
net session >nul 2>&1
if not %errorlevel%==0 (
  set "__ARGS=%*"
  powershell -NoProfile -ExecutionPolicy Bypass -Command ^
    "$args = if($env:__ARGS){ @($env:__ARGS.Split(' ')) } else { @() }; " ^
    "if ($args.Count -gt 0) { Start-Process -FilePath '%ROOT%\Build-All.cmd' -Verb RunAs -ArgumentList $args } else { Start-Process -FilePath '%ROOT%\Build-All.cmd' -Verb RunAs }"
  exit /b
)

echo.
echo [INFO] Lancement Build-All.ps1...
echo.

"%PWSH%" -NoProfile -ExecutionPolicy Bypass -STA -File "%ROOT%\Build-All.ps1" -LogPath "%LOG%" %*
set "BUILD_ERRORLEVEL=%errorlevel%"

echo.
echo [INFO] Build terminé avec code d'erreur: %BUILD_ERRORLEVEL%
echo [INFO] Log complet: %LOG%
echo.
pause

exit /b %BUILD_ERRORLEVEL%
