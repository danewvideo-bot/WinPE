@echo off
REM Test Build-All.cmd - Verification rapide

cd /d "%~dp0"

echo.
echo ===============================================
echo  TEST BUILD-ALL.CMD
echo ===============================================
echo.

REM Verification version
echo [1] Version du projet:
type VERSION
echo.

REM Verification fichiers cles
echo [2] Fichiers cles:
if exist "Build-All.ps1" (
  echo   [OK] Build-All.ps1
) else (
  echo   [XX] Build-All.ps1 NOT FOUND
  goto :error
)

if exist "config.psd1" (
  echo   [OK] config.psd1
) else (
  echo   [XX] config.psd1 NOT FOUND
  goto :error
)

if exist "launcher.ps1" (
  echo   [OK] launcher.ps1
) else (
  echo   [XX] launcher.ps1 NOT FOUND
  goto :error
)

echo.

REM Verification admin
echo [3] Droits administrateur:
net session >nul 2>&1
if %errorlevel%==0 (
  echo   [OK] Admin requis
) else (
  echo   [XX] Admin manquant
  echo.
  echo Pour relancer en admin:
  echo   Clic-droit sur ce fichier ^> Executer en tant qu'administrateur
  echo.
  pause
  exit /b 1
)

echo.

REM Detection PowerShell
echo [4] PowerShell disponible:
where pwsh >nul 2>nul
if %errorlevel%==0 (
  echo   [OK] PowerShell Core (pwsh) trouve
  set "PWSH=pwsh"
) else (
  echo   [OK] PowerShell Desktop (powershell) utilise
  set "PWSH=powershell"
)

echo.

REM Creation dossier logs
if not exist "logs" mkdir logs
echo [5] Logs: logs\ (OK)

echo.
echo ===============================================
echo  RESULTAT: TOUS LES TESTS PASSENT!
echo ===============================================
echo.
echo Vous pouvez maintenant lancer Build-All.cmd
echo.
pause

exit /b 0

:error
echo.
echo Erreur: Fichiers manquants. Verifiez la structure du projet.
echo.
pause
exit /b 1
