#requires -Version 7.0
[CmdletBinding()]
param(
  [ValidateSet("none","patch","minor","major")]
  [string] $Bump = "patch",

  [switch] $Stamp,

  [switch] $NoExe,
  [switch] $NoWinPE,
  [switch] $NoPortable,

  [switch] $SyncUsb,
  [switch] $SyncUsbWhatIf,
  [switch] $SyncUsbOptional,

  [string] $UsbLabel = "DANEW",
  [string] $UsbDestSubDir = "Danew",
  [switch] $UsbMirror,

  [string] $LogPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

function Assert-Admin {
  $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
  ).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
  if (-not $isAdmin) { throw "Admin requis. Lance Build-All.cmd (clic droit > Exécuter en tant qu'admin)." }
}

function Step([string]$msg) {
  Write-Host ""
  Write-Host ">>> $msg" -ForegroundColor Cyan
}

function Resolve-OptionalScript([string]$p) {
  if (-not (Test-Path -LiteralPath $p)) { throw "Script introuvable: $p" }
  return (Resolve-Path -LiteralPath $p).Path
}

Assert-Admin

# CRITICAL: v4 DISM CLEANUP AT STARTUP
# ======================================
# DISM can have orphaned mounts from previous runs even across reboot.
# We MUST clean them FIRST before ANY operations.
Write-Host ">>> CRITICAL STARTUP: DISM Orphan Cleanup (v4)" -ForegroundColor Magenta
try {
  $dism = Join-Path $env:WINDIR "System32\dism.exe"
  
  # Multiple cleanup attempts to ensure complete clearing
  Write-Host "  [1/3] Initial cleanup..." -ForegroundColor Gray
  & $dism /Cleanup-Mountpoints 2>&1 | Out-Null
  
  Start-Sleep -Milliseconds 500
  
  Write-Host "  [2/3] Force workspace removal..." -ForegroundColor Gray
  $workspaces = @("C:\Temp\DanewWinPE", "C:\Temp\DanewWinPE_Old", "C:\Temp\DanewWinPE_Backup")
  foreach ($ws in $workspaces) {
    if (Test-Path -LiteralPath $ws) {
      try {
        Remove-Item -LiteralPath $ws -Recurse -Force -ErrorAction Stop
        Write-Host "    ✓ Removed: $ws" -ForegroundColor DarkGreen
      } catch {
        Write-Host "    ✗ Failed to remove $ws (will retry): $_" -ForegroundColor DarkYellow
      }
    }
  }
  
  Start-Sleep -Milliseconds 500
  
  Write-Host "  [3/3] Final cleanup..." -ForegroundColor Gray
  & $dism /Cleanup-Mountpoints 2>&1 | Out-Null
  
  Write-Host "  ✅ v4 Startup cleanup complete" -ForegroundColor Green
} catch {
  Write-Host "  ⚠️  Startup cleanup failed (non-critical): $_" -ForegroundColor Yellow
}

# ----------------------------
# Transcript (LOG)
# ----------------------------
$transcriptStarted = $false
try {
  if (-not $LogPath) {
    $logDir = Join-Path $PSScriptRoot "logs"
    New-Item -ItemType Directory -Path $logDir -Force | Out-Null
    $LogPath = Join-Path $logDir ("build-all_{0}.log" -f (Get-Date -Format "yyyyMMdd_HHmmss"))
  } else {
    $logDir = Split-Path $LogPath -Parent
    if ($logDir) { New-Item -ItemType Directory -Path $logDir -Force | Out-Null }
  }

  Start-Transcript -Path $LogPath -Append | Out-Null
  $transcriptStarted = $true
  Write-Host "[LOG] Transcript started: $LogPath" -ForegroundColor DarkGray
} catch {
  Write-Host "[LOG] WARNING: failed to start transcript: $($_.Exception.Message)" -ForegroundColor Yellow
}

$root = $PSScriptRoot

try {
  # =========================================================
  # 0) Versioning
  # =========================================================
  Step "Versioning"
  $getVer = Resolve-OptionalScript (Join-Path $root "Get-Version.ps1")
  $ver = & $getVer -Bump $Bump -Stamp:$Stamp
  if (-not $ver) { throw "Version vide retournée par Get-Version.ps1" }
  Write-Host "Version build: $ver" -ForegroundColor Green
  $env:DANEW_VERSION = $ver

  # =========================================================
  # 1) Write payload\VERSION
  # =========================================================
  Step "Write payload\VERSION"
  $payloadDir = Join-Path $root "payload"
  if (-not (Test-Path -LiteralPath $payloadDir)) { throw "Dossier payload introuvable: $payloadDir" }

  $payloadVersion = Join-Path $payloadDir "VERSION"
  $ver | Set-Content -Path $payloadVersion -Encoding UTF8

  # =========================================================
  # 2) Build PORTABLE (ZIP + optional EXE)
  # =========================================================
  if (-not $NoPortable) {
    Step "Build portable (ZIP)"
    $bp = Resolve-OptionalScript (Join-Path $root "Build-Portable.ps1")
    & $bp

    if (-not $NoExe) {
      Step "Build portable (EXE)"
      & $bp -BuildExe -OnlyExe
    } else {
      Write-Host "NoExe activé — EXE ignoré" -ForegroundColor Yellow
    }
  } else {
    Write-Host "NoPortable activé — portable ignoré" -ForegroundColor Yellow
  }

  # =========================================================
  # 3) UI WinPE (Create USB)
  # =========================================================
  if (-not $NoWinPE) {
    Step "Create WinPE USB (UI)"
    $nw = Resolve-OptionalScript (Join-Path $root "New-DanewUsbWizard.ps1")

    # IMPORTANT: Build-All.cmd lance déjà pwsh en -STA, donc l'UI WPF fonctionne sans relaunch.
    & $nw
  } else {
    Write-Host "NoWinPE activé — WinPE ignoré" -ForegroundColor Yellow
  }

  # =========================================================
  # 4) Auto Sync payload -> USB (DANEW:\Danew)
  # =========================================================
  if ($SyncUsb) {
    Step "Auto-Sync payload -> USB (${UsbLabel}:\${UsbDestSubDir})"

    $sync = Resolve-OptionalScript (Join-Path $root "Sync-Payload.ps1")
    $vol = Get-Volume -FileSystemLabel $UsbLabel -ErrorAction SilentlyContinue |
           Where-Object DriveLetter |
           Select-Object -First 1

    if (-not $vol) {
      if ($SyncUsbOptional) {
        Write-Host "USB Sync demandé mais clé '$UsbLabel' absente — SKIP (SyncUsbOptional)." -ForegroundColor Yellow
      } else {
        throw "USB Sync demandé mais volume label '$UsbLabel' introuvable."
      }
    } else {
      $args = @{
        PayloadRoot = $payloadDir
        TargetLabel = $UsbLabel
        DestSubDir  = $UsbDestSubDir
      }
      if ($UsbMirror)     { $args.Mirror = $true }
      if ($SyncUsbWhatIf) { $args.WhatIfCopy = $true }

      & $sync @args
    }
  } else {
    Write-Host "SyncUsb non activé — aucune copie automatique vers la clé." -ForegroundColor DarkGray
  }

  Step "DONE"
  Write-Host "Build-All terminé avec succès | Version: $ver" -ForegroundColor Green
}
catch {
  Write-Host ""
  Write-Host "[ERROR] $($_.Exception.Message)" -ForegroundColor Red
  Write-Host "Log: $LogPath" -ForegroundColor Yellow
  throw
}
finally {
  if ($transcriptStarted) {
    try { Stop-Transcript | Out-Null } catch {}
    Write-Host "[LOG] Transcript finished: $LogPath" -ForegroundColor DarkGray
  }
}
