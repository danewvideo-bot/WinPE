@echo off
REM Lance le diagnostic en tant qu'administrateur

cd /d "%~dp0"

echo Lancement du diagnostic (droits admin requis)...
echo.

powershell -NoProfile -ExecutionPolicy Bypass -Command ^
  "Start-Process powershell -ArgumentList '-STA -NoProfile -ExecutionPolicy Bypass -File ""%CD%\Build-All-Diagnostic.ps1""' -Verb RunAs -Wait"

pause
