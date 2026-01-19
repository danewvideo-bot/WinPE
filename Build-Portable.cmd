@echo off
setlocal EnableExtensions EnableDelayedExpansion

REM =====================================================
REM Danew USB Wizard - Build Portable ZIP
REM =====================================================

set ROOT=%~dp0
set DIST=%ROOT%dist
set ZIP=%DIST%\DanewUsbWizard_Portable.zip

echo ===============================================
echo  Danew USB Wizard - Build Portable ZIP
echo ===============================================

REM -----------------------------------------------------
REM Clean dist
REM -----------------------------------------------------
if exist "%DIST%" (
    echo [INFO] Nettoyage du dossier dist
    rmdir /s /q "%DIST%"
)

mkdir "%DIST%" || goto :error

REM -----------------------------------------------------
REM Copy required files
REM -----------------------------------------------------
echo [INFO] Copie des fichiers...

if exist "%ROOT%DanewUsbWizard.exe" (
    copy "%ROOT%DanewUsbWizard.exe" "%DIST%" >nul
) else (
    echo [WARN] DanewUsbWizard.exe absent (mode script uniquement)
)

copy "%ROOT%RunDanewUsbWizard.cmd" "%DIST%" >nul

copy "%ROOT%Start-DanewUsbWizard.ps1" "%DIST%" >nul
copy "%ROOT%New-DanewUsbWizard.ps1" "%DIST%" >nul
copy "%ROOT%config.psd1" "%DIST%" >nul

xcopy "%ROOT%modules" "%DIST%\modules" /E /I /Y >nul
xcopy "%ROOT%payload" "%DIST%\payload" /E /I /Y >nul
xcopy "%ROOT%pwsh" "%DIST%\pwsh" /E /I /Y >nul

REM -----------------------------------------------------
REM Create ZIP (PowerShell native)
REM -----------------------------------------------------
echo [INFO] Création du ZIP...

powershell -NoProfile -Command ^
  "Compress-Archive -Path '%DIST%\*' -DestinationPath '%ZIP%' -Force"

if not exist "%ZIP%" goto :error

echo.
echo [OK] ZIP portable créé :
echo %ZIP%
echo.
echo 👉 Lanceur : RunDanewUsbWizard.cmd
echo.
pause
exit /b 0

:error
echo.
echo [ERREUR] Échec de génération du ZIP
pause
exit /b 1
