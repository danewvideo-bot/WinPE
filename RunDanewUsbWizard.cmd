@echo off
setlocal
cd /d "%~dp0"

REM Lance l'EXE si présent (console visible si build sans -noConsole)
if exist "DanewUsbWizard.exe" (
  DanewUsbWizard.exe
  exit /b %errorlevel%
)

REM Sinon, lance le script via PowerShell 7 portable (console visible)
if exist "pwsh\pwsh.exe" (
  pwsh\pwsh.exe -NoProfile -ExecutionPolicy Bypass -STA -File "New-DanewUsbWizard.ps1"
  exit /b %errorlevel%
)

REM Fallback Windows PowerShell 5.1 (console visible)
powershell.exe -NoProfile -ExecutionPolicy Bypass -STA -File "New-DanewUsbWizard.ps1"
exit /b %errorlevel%
