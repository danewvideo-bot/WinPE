@echo off
setlocal
cd /d "%~dp0"

REM Lance PowerShell avec une exécution fiable (WinPE/Windows)
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Start-DanewUsbWizard.ps1"
exit /b %errorlevel%
