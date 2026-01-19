@echo off
REM =====================================================
REM Danew USB Wizard - Build Diagnostic
REM =====================================================
REM Vérifie les prérequis et prépare l'environnement
REM pour le build. Lance si tout est OK.
REM =====================================================

setlocal EnableExtensions EnableDelayedExpansion
chcp 65001 >nul
cd /d "%~dp0"
set "ROOT=%CD%"

echo.
echo ===============================================
echo  Danew USB Wizard - Diagnostic de Build
echo ===============================================
echo.

REM Vérification admin
echo [CHECK] Vérification droits administrateur...
net session >nul 2>&1
if not %errorlevel%==0 (
  set "__ARGS=%*"
  powershell -NoProfile -ExecutionPolicy Bypass -Command ^
    "$args = if($env:__ARGS){ @($env:__ARGS.Split(' ')) } else { @() }; " ^
    "if ($args.Count -gt 0) { Start-Process -FilePath '%ROOT%\Build-All-Debug.cmd' -Verb RunAs -ArgumentList $args } else { Start-Process -FilePath '%ROOT%\Build-All-Debug.cmd' -Verb RunAs }"
  exit /b
)
echo [✓] Administrateur OK
echo.

REM Vérification PowerShell
echo [CHECK] Checking PowerShell...
where /q pwsh.exe
if %errorlevel%==0 (
  set "PWSH=pwsh"
  echo [OK] PowerShell Core found
) else (
  where /q powershell.exe
  if %errorlevel%==0 (
    set "PWSH=powershell"
    echo [OK] PowerShell Desktop found
  ) else (
    echo [ERROR] PowerShell not found!
    echo.
    pause
    exit /b 1
  )
)
echo.

REM Afficher version PowerShell
echo [INFO] Version PowerShell:
"%PWSH%" -NoProfile -Command "$PSVersionTable.PSVersion"
echo.

REM Vérification fichiers clés
echo [CHECK] Vérification fichiers clés...
if not exist "%ROOT%\Build-All.ps1" (
  echo [ERROR] Build-All.ps1 non trouvé!
  pause
  exit /b 1
)
echo [✓] Build-All.ps1 présent
echo.

REM Vérification config
echo [CHECK] Vérification fichiers configuration...
if not exist "%ROOT%\config.psd1" (
  echo [WARNING] config.psd1 non trouvé (créé au runtime)
)
echo [✓] Configuration OK
echo.

REM Vérification ADK (optionnel mais important)
echo [CHECK] Vérification ADK Windows...
where copype.exe >nul 2>nul
if %errorlevel%==0 (
  echo [✓] copype.exe trouvé
) else (
  echo [WARNING] copype.exe non trouvé (requis pour WinPE)
  echo          Installer Windows ADK: https://docs.microsoft.com/en-us/windows-hardware/get-started/adk-install
)
echo.

REM Création répertoire logs
if not exist "%ROOT%\logs" mkdir "%ROOT%\logs"
echo [✓] Répertoire logs créé
echo.

REM Prêt à lancer
echo ===============================================
echo  Tous les tests passés! Lancement du build...
echo ===============================================
echo.

REM Lancer Build-All.ps1 avec verbose
"%PWSH%" -NoProfile -ExecutionPolicy Bypass -STA ^
  -Command "& '%ROOT%\Build-All.ps1' -LogPath '%ROOT%\logs\build-all.log'" %*

set "ERRORLEVEL=%errorlevel%"

echo.
echo ===============================================
if %ERRORLEVEL%==0 (
  echo [✓] Build terminé avec succès!
) else (
  echo [ERROR] Build échoué avec code d'erreur: %ERRORLEVEL%
  echo [INFO] Vérifiez les logs: %ROOT%\logs\
)
echo ===============================================
echo.

pause
exit /b %ERRORLEVEL%
