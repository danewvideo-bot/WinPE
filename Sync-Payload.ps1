# Sync-Payload.ps1
# Synchronise le payload DEV vers la partition DANEW:\Danew
# SAFE: aucune opération disque destructive

#requires -Version 5.1

param(
  [Parameter(Mandatory)][string]$PayloadRoot,
  [string]$TargetLabel = "DANEW",
  [string]$DestSubDir = "Danew",
  [switch]$Mirror,          # si présent: /MIR (dangereux si tu as des fichiers manuels sur la clé)
  [switch]$WhatIfCopy       # simulation: affiche les commandes robocopy sans copier
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# --- SECURITY GUARD: PayloadRoot must be ...\payload
$resolved = Resolve-Path -LiteralPath $PayloadRoot
if ((Split-Path -Leaf $resolved.Path) -ne "payload") {
  throw "SECURITY: PayloadRoot doit pointer vers le dossier 'payload' uniquement. Reçu: $($resolved.Path)"
}

Write-Host "=== Danew Payload Sync ==="

# Resolve source
$src = $resolved.Path
if ($src[-1] -ne '\') { $src += '\' }

# Find target volume by label
$vol = Get-Volume -FileSystemLabel $TargetLabel -ErrorAction SilentlyContinue |
       Where-Object DriveLetter |
       Select-Object -First 1

if (-not $vol) {
  throw "Partition '$TargetLabel' introuvable. Vérifie que la clé est branchée et que la partition NTFS a le label DANEW."
}

# --- SAFETY GUARD: target volume must be on a USB disk
try {
  $part = Get-Partition -DriveLetter $vol.DriveLetter -ErrorAction Stop | Select-Object -First 1
  $disk = Get-Disk -Number $part.DiskNumber -ErrorAction Stop

  if ($disk.BusType -ne "USB") {
    throw "SECURITY: La cible '$TargetLabel' n'est pas sur un disque USB (Disk #$($disk.Number), BusType=$($disk.BusType), Name=$($disk.FriendlyName)). Refus."
  }

  if ($disk.IsSystem -or $disk.IsBoot) {
    throw "SECURITY: La cible '$TargetLabel' est sur un disque système/boot (Disk #$($disk.Number)). Refus."
  }

  Write-Host ("Disk OK: #{0} {1} {2}GB USB" -f $disk.Number, $disk.FriendlyName, [Math]::Round($disk.Size/1GB,1))
}
catch {
  throw "SECURITY: Impossible de valider la cible USB pour '$TargetLabel' (Drive $($vol.DriveLetter):). Détails: $($_.Exception.Message)"
}

$dstRoot = "$($vol.DriveLetter):\$DestSubDir"
if (-not (Test-Path -LiteralPath $dstRoot)) {
  Write-Host "Creating $dstRoot"
  New-Item -ItemType Directory -Path $dstRoot -Force | Out-Null
}

$dst = (Resolve-Path -LiteralPath $dstRoot).Path
if ($dst[-1] -ne '\') { $dst += '\' }

Write-Host "Target: Disk label=$TargetLabel Drive=$($vol.DriveLetter):\  -> $dst"
Write-Host "Source: $src"

# Robocopy args
$robocopy = Join-Path $env:WINDIR "System32\robocopy.exe"

# Copy options
$common = @("/E","/R:1","/W:1","/NFL","/NDL","/NP","/XD","winpe")

# /MIR option (optional, use carefully)
$syncMode = @()
if ($Mirror) { $syncMode = @("/MIR") }

$argList = @($src, $dst) + $syncMode + $common

Write-Host "ROBOCOPY $($argList -join ' ')"

if (-not $WhatIfCopy) {
  $p = Start-Process -FilePath $robocopy -ArgumentList $argList -NoNewWindow -PassThru -Wait

  # robocopy success codes: 0..7
  if ($p.ExitCode -gt 7) {
    throw "Robocopy failed (ExitCode=$($p.ExitCode))"
  }

  Write-Host "Payload sync completed successfully. (ExitCode=$($p.ExitCode))"
} else {
  Write-Host "WHATIF: no copy performed."
}
