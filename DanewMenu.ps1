# DanewMenu.ps1 - V3.1 FINAL (WinPE)
# - Banner (Smoke Check) always visible
# - Safe config parsing under StrictMode
# - Menu + SystemRepair module integration
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Pause-AnyKey {
    Write-Host ""
    Read-Host "Appuyez sur Entrée pour continuer" | Out-Null
}

function Show-Banner {
    $payloadRoot = "X:\Danew"
    $configPath  = Join-Path $payloadRoot "config.json"
    $versionPath = Join-Path $payloadRoot "VERSION"

    $selfTestEnabled = $true
    $selfTestOnBoot  = $false
    $selfTestFail    = "warn"
    $logPath         = "X:\Danew\Logs"
    $version         = "unknown"

    if (Test-Path $versionPath) {
        try { $version = (Get-Content $versionPath -Raw).Trim() } catch {}
    }

    if (Test-Path $configPath) {
        try {
            $cfg = Get-Content $configPath -Raw | ConvertFrom-Json
            if ($cfg.selfTest.enabled -ne $null) { $selfTestEnabled = [bool]$cfg.selfTest.enabled }
            if ($cfg.selfTest.onBoot  -ne $null) { $selfTestOnBoot  = [bool]$cfg.selfTest.onBoot }
            if ($cfg.selfTest.failMode)          { $selfTestFail    = $cfg.selfTest.failMode }
            if ($cfg.logging.forcePath)          { $logPath         = $cfg.logging.forcePath }
        } catch {}
    }

    Write-Host "==========================================" -ForegroundColor DarkGray
    Write-Host " DANEW USB WIZARD  |  Version $version"   -ForegroundColor Cyan
    Write-Host "------------------------------------------" -ForegroundColor DarkGray
    Write-Host (" SelfTest : {0} (onBoot={1}, mode={2})" -f `
        ($selfTestEnabled ? "ENABLED" : "DISABLED"),
        $selfTestOnBoot,
        $selfTestFail
    )
    Write-Host (" Logs     : {0}" -f $logPath)
    Write-Host "==========================================" -ForegroundColor DarkGray
    Write-Host ""
}

function Show-Menu {
    Clear-Host
    Show-Banner

    Write-Host "=== DANEW WinPE Toolkit ==="
    Write-Host ""
    Write-Host "1) Réparer le boot UEFI (AUTO)"
    Write-Host "2) Détecter l'installation Windows"
    Write-Host "3) Appliquer une image Windows (WIM/SWM) sur un disque"
    Write-Host "4) Exporter le rapport (JSON/TXT)"
    Write-Host "9) SelfTest (diagnostic intégration - SAFE)"
    Write-Host "0) Quitter"
    Write-Host ""
}

# --- Import module ---
$modulePath = Join-Path $PSScriptRoot "modules\Danew.SystemRepair.psm1"
if (-not (Test-Path $modulePath)) {
    Write-Host "ERREUR: module introuvable: $modulePath" -ForegroundColor Red
    Pause-AnyKey
    exit 1
}
Import-Module $modulePath -Force

# --- Optional config.json (log path) ---
$cfgPath = Join-Path $PSScriptRoot "config.json"
$cfg = $null
if (Test-Path $cfgPath) {
    try { $cfg = Get-Content $cfgPath -Raw | ConvertFrom-Json } catch { $cfg = $null }
}

# Safe read of logging.forcePath under StrictMode
$logRoot = $null
try {
    if ($cfg -and ($cfg.PSObject.Properties.Name -contains 'logging')) {
        $logging = $cfg.logging
        if ($logging -and ($logging.PSObject.Properties.Name -contains 'forcePath')) {
            $logRoot = $logging.forcePath
        }
    }
} catch { $logRoot = $null }

$session = Initialize-DanewSession -ForcePath $logRoot -Prefix "DanewUsbWizard" -Quiet:$false

$summary = [ordered]@{
    result          = "unknown"
    lastAction      = $null
    windowsDetected = $null
}

try {
    while ($true) {
        Show-Menu
        $choice = Read-Host "Choix"

        switch ($choice) {

            "1" {
                $summary.lastAction = "BootRepairAuto"

                $r = Invoke-DanewBootRepairAuto

                if ($r -and ($r.PSObject.Properties.Name -contains "WindowsDrive") -and ($r.PSObject.Properties.Name -contains "EspDrive")) {
                    $summary.windowsDetected = $r.WindowsDrive
                    Write-Host ""
                    Write-Host ("OK: Windows={0} | ESP={1}" -f $r.WindowsDrive, $r.EspDrive)
                } else {
                    Write-Host ""
                    Write-Host "OK: réparation EFI exécutée."
                }

                Pause-AnyKey
            }

            "2" {
                $summary.lastAction = "DetectWindows"
                $w = Get-DanewWindowsInstall
                Write-Host ""
                if ($w) {
                    $summary.windowsDetected = $w.Drive
                    Write-Host ("Windows détecté: {0} ({1})" -f $w.Drive, $w.WindowsPath)
                } else {
                    Write-Host "Aucune installation Windows détectée."
                }
                Pause-AnyKey
            }

            "3" {
                $summary.lastAction = "ApplyImage"
                $src = Read-Host "Chemin image (fichier .wim/.swm OU dossier)"
                $tgt = Read-Host "Lettre cible (ex: C:)"
                $idx = Read-Host "Index (défaut 1)"
                if ([string]::IsNullOrWhiteSpace($idx)) { $idx = 1 }

                Apply-DanewWindowsImage -ImageSourcePath $src -TargetDrive $tgt -Index ([int]$idx) -ForcePath $session.LogRoot | Out-Null
                Write-Host ""
                Write-Host "Image appliquée avec succès."
                Pause-AnyKey
            }

            "4" {
                $summary.lastAction = "ExportReport"
                $r = Export-DanewReport -Name "DanewUsbWizard" -Summary $summary
                Write-Host ""
                Write-Host ("Report JSON: {0}" -f $r.Json)
                Write-Host ("Report TXT : {0}" -f $r.Txt)
                Pause-AnyKey
            }

            "9" {
                $summary.lastAction = "SelfTest"
                $selfTest = Join-Path $PSScriptRoot "SelfTest.ps1"
                if (Test-Path $selfTest) {
                    # Run in a child PowerShell to avoid hard exits killing the menu
                    powershell.exe -NoProfile -ExecutionPolicy Bypass -File $selfTest
                    Pause-AnyKey
                } else {
                    Write-Host "SelfTest.ps1 introuvable dans le payload." -ForegroundColor Red
                    Pause-AnyKey
                }
            }

            "0" {
                $summary.result = "exit"
                break
            }

            default {
                Write-Host "Choix invalide."
                Pause-AnyKey
            }
        }
    }
}
catch {
    $summary.result = "error"
    Write-DanewLog -Level ERROR -Message "Menu exception" -Data @{ error="$($_.Exception.Message)" }
    try { Export-DanewReport -Name "DanewUsbWizard" -Summary $summary | Out-Null } catch {}
    throw
}
finally {
    if ($summary.result -eq "unknown") { $summary.result = "ok" }
    try { Export-DanewReport -Name "DanewUsbWizard" -Summary $summary | Out-Null } catch {}
}
