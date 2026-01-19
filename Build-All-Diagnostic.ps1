#requires -Version 5.1
<#
.SYNOPSIS
Diagnostic et verification des prerequis pour le build Danew USB Wizard

.DESCRIPTION
Verifie:
- Droits administrateur
- Presence PowerShell
- Fichiers de configuration
- ADK Windows (copype, MakeWinPEMedia)
- Espace disque
- Modules PowerShell
#>

param(
  [switch]$FixIssues
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$Root = Split-Path -Parent $MyInvocation.MyCommand.Path
$Passed = 0
$Failed = 0
$Warnings = 0

function Write-Check {
  param([string]$Message, [string]$Status)
  $colorMap = @{
    "PASS" = "Green"
    "FAIL" = "Red"
    "WARN" = "Yellow"
  }
  
  $statusSymbol = @{
    "PASS" = "[OK]"
    "FAIL" = "[XX]"
    "WARN" = "[!]"
  }[$Status]
  
  $color = $colorMap[$Status]
  Write-Host "$statusSymbol $Message" -ForegroundColor $color
}

function Write-Section {
  param([string]$Title)
  Write-Host ""
  Write-Host "==================================================" -ForegroundColor Cyan
  Write-Host "  $Title" -ForegroundColor Cyan
  Write-Host "==================================================" -ForegroundColor Cyan
}

# ============================================================================
# 1. ADMIN CHECK
# ============================================================================
Write-Section "1. Verification des Droits Administrateur"

$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if ($isAdmin) {
  Write-Check "Droits administrateur" "PASS"
  $Passed++
} else {
  Write-Check "Droits administrateur (MANQUANTS)" "FAIL"
  Write-Host "  -> Relancez avec clic-droit > Executer en tant qu'administrateur" -ForegroundColor Yellow
  $Failed++
  exit 1
}

# ============================================================================
# 2. POWERSHELL VERSION
# ============================================================================
Write-Section "2. Verification PowerShell"

Write-Check "PowerShell version: $($PSVersionTable.PSVersion)" "PASS"
$Passed++

if ($PSVersionTable.PSVersion.Major -lt 5) {
  Write-Check "PowerShell version requise: 5.1+ (vous avez $($PSVersionTable.PSVersion))" "FAIL"
  $Failed++
}

# STA Mode check
$isStaMode = [System.Threading.Thread]::CurrentThread.ApartmentState -eq 'STA'
if ($isStaMode) {
  Write-Check "Mode STA (requis pour WPF)" "PASS"
  $Passed++
} else {
  Write-Check "Mode STA (optionnel pour diagnostics)" "WARN"
  Write-Host "  -> Pour UI, lancer avec: powershell -STA -File Build-All-Diagnostic.ps1" -ForegroundColor Yellow
  $Warnings++
}

# ============================================================================
# 3. FICHIERS CLES
# ============================================================================
Write-Section "3. Verification Fichiers Cles"

$requiredFiles = @(
  "Build-All.ps1",
  "config.psd1",
  "launcher.ps1",
  "VERSION"
)

foreach ($file in $requiredFiles) {
  $path = Join-Path $Root $file
  if (Test-Path -LiteralPath $path) {
    Write-Check "$file" "PASS"
    $Passed++
  } else {
    Write-Check "$file (MANQUANT)" "FAIL"
    $Failed++
  }
}

# ============================================================================
# 4. MODULES POWERSHELL
# ============================================================================
Write-Section "4. Verification Modules PowerShell"

$modulesToCheck = @(
  "modules\Danew.UI.psm1",
  "modules\Danew.WinPE.psm1",
  "modules\Danew.EFI.psm1",
  "modules\Danew.Disk.psm1",
  "modules\Danew.Common.psm1"
)

foreach ($mod in $modulesToCheck) {
  $path = Join-Path $Root $mod
  if (Test-Path -LiteralPath $path) {
    Write-Check (Split-Path -Leaf $mod) "PASS"
    $Passed++
  } else {
    Write-Check (Split-Path -Leaf $mod) "WARN"
    $Warnings++
  }
}

# ============================================================================
# 5. PAYLOAD WinPE
# ============================================================================
Write-Section "5. Verification Payload WinPE"

$payloadFiles = @(
  "payload\DanewMenu.ps1",
  "payload\SelfTest.ps1",
  "payload\RunFix.cmd",
  "payload\config.json"
)

foreach ($pfile in $payloadFiles) {
  $path = Join-Path $Root $pfile
  if (Test-Path -LiteralPath $path) {
    Write-Check (Split-Path -Leaf $pfile) "PASS"
    $Passed++
  } else {
    Write-Check (Split-Path -Leaf $pfile) "WARN"
    $Warnings++
  }
}

# ============================================================================
# 6. ASSEMBLIES .NET (WPF)
# ============================================================================
Write-Section "6. Verification Assemblies .NET (WPF)"

$assemblies = @("PresentationFramework", "PresentationCore", "WindowsBase")
foreach ($asm in $assemblies) {
  try {
    Add-Type -AssemblyName $asm -ErrorAction Stop
    Write-Check "Assembly: $asm" "PASS"
    $Passed++
  }
  catch {
    Write-Check "Assembly: $asm (NON DISPONIBLE)" "WARN"
    Write-Host "  -> $($_.Exception.Message)" -ForegroundColor Yellow
    $Warnings++
  }
}

# ============================================================================
# 7. ADK WINDOWS (COPYPE, MAKEWINPEMEDIA)
# ============================================================================
Write-Section "7. Verification ADK Windows"

$adkTools = @("copype.exe", "MakeWinPEMedia.exe", "bcdboot.exe")
$adkFound = $false

foreach ($tool in $adkTools) {
  $toolPath = (Get-Command $tool -ErrorAction SilentlyContinue).Source
  if ($toolPath) {
    Write-Check "ADK: $tool" "PASS"
    Write-Host "     Chemin: $toolPath" -ForegroundColor Gray
    $Passed++
    $adkFound = $true
  }
  else {
    Write-Check "ADK: $tool (NON TROUVE)" "FAIL"
    $Failed++
  }
}

if (-not $adkFound) {
  Write-Host ""
  Write-Host "  [!] ADK Windows n'est pas installe ou n'est pas dans le PATH" -ForegroundColor Yellow
  Write-Host ""
  Write-Host "  Installation:" -ForegroundColor Cyan
  Write-Host "  1. Telecharger Windows ADK: https://docs.microsoft.com/en-us/windows-hardware/get-started/adk-install" -ForegroundColor White
  Write-Host "  2. Installer 'Deployment Tools'" -ForegroundColor White
  Write-Host "  3. Ajouter au PATH ou redémarrer PowerShell" -ForegroundColor White
  Write-Host ""
}

# ============================================================================
# 8. ESPACE DISQUE
# ============================================================================
Write-Section "8. Verification Espace Disque"

$diskInfo = Get-PSDrive -Name "C" -ErrorAction SilentlyContinue
if ($diskInfo) {
  $freeGB = [math]::Round($diskInfo.Free / 1GB, 2)
  $totalGB = [math]::Round($diskInfo.Used / 1GB + $diskInfo.Free / 1GB, 2)
  
  if ($freeGB -gt 5) {
    Write-Check "Espace disque C: $freeGB GB libre / $totalGB GB total" "PASS"
    $Passed++
  }
  else {
    Write-Check "Espace disque INSUFFISANT: $freeGB GB libre (besoin 5+ GB)" "FAIL"
    $Failed++
  }
}

# ============================================================================
# 9. CONFIGURATION
# ============================================================================
Write-Section "9. Verification Configuration"

$configPath = Join-Path $Root "config.psd1"
if (Test-Path -LiteralPath $configPath) {
  try {
    $config = Invoke-Expression (Get-Content $configPath -Raw)
    Write-Check "config.psd1 valide" "PASS"
    Write-Host "     Arch: $($config.Arch)" -ForegroundColor Gray
    Write-Host "     WorkDir: $($config.WorkDir)" -ForegroundColor Gray
    Write-Host "     MinUsbSizeGB: $($config.MinUsbSizeGB)" -ForegroundColor Gray
    $Passed++
  }
  catch {
    Write-Check "config.psd1 INVALIDE" "FAIL"
    Write-Host "     Erreur: $($_.Exception.Message)" -ForegroundColor Red
    $Failed++
  }
}

# ============================================================================
# 10. USB DEVICES
# ============================================================================
Write-Section "10. Verification Disques USB"

try {
  $usbDisks = Get-Disk | Where-Object { $_.BusType -eq "USB" -and -not $_.IsSystem }
  if ($usbDisks) {
    Write-Check "Disques USB detectes: $($usbDisks.Count)" "PASS"
    $Passed++
    foreach ($disk in $usbDisks) {
      $sizeGB = [math]::Round($disk.Size / 1GB, 2)
      Write-Host "     - Disk$($disk.Number): $($disk.FriendlyName) ($sizeGB GB)" -ForegroundColor Gray
    }
  }
  else {
    Write-Check "Aucun disque USB detecte (optionnel)" "WARN"
    $Warnings++
  }
}
catch {
  Write-Check "Verification USB echouee" "WARN"
  Write-Host "     $($_.Exception.Message)" -ForegroundColor Gray
  $Warnings++
}

# ============================================================================
# DIAGNOSTIC AVANCÉ (Module Danew.Diagnostic.psm1)
# ============================================================================
Write-Section "DIAGNOSTIC AVANCÉ (Danew.Diagnostic.psm1)"

try {
  $diagnosticModule = Join-Path $Root "modules\Danew.Diagnostic.psm1"
  if (Test-Path -LiteralPath $diagnosticModule) {
    Import-Module $diagnosticModule -Force -ErrorAction Stop
    Write-Host "[OK] Module Danew.Diagnostic importé" -ForegroundColor Green
    
    # Lancer diagnostic complet
    $diagResults = Invoke-DanewDiagnostic `
      -RootPath $Root `
      -Mode "CLI" `
      -MinDiskSpaceGB 5 `
      -MinUsbSizeGB 7
    
    # Résumer résultats
    $diagPass = @($diagResults | Where-Object { $_.Passed }).Count
    $diagFail = @($diagResults | Where-Object { -not $_.Passed -and -not $_.Warning }).Count
    $diagWarn = @($diagResults | Where-Object { $_.Warning -and -not $_.Passed }).Count
    
    Write-Host "[OK] Diagnostic résumé: $diagPass passed, $diagFail failed, $diagWarn warnings" -ForegroundColor Gray
  }
  else {
    Write-Host "[!] Module Danew.Diagnostic non trouvé (diagnostic limité au script legacy)" -ForegroundColor Yellow
  }
}
catch {
  Write-Host "[!] Erreur import Danew.Diagnostic: $($_.Exception.Message)" -ForegroundColor Yellow
}

# ============================================================================
# RESUME
# ============================================================================
Write-Section "RESUME DES DIAGNOSTICS"

Write-Host ""
Write-Host "[OK] Tests reussis:  $Passed" -ForegroundColor Green
Write-Host "[XX] Tests echoues:  $Failed" -ForegroundColor $(if ($Failed -gt 0) { "Red" } else { "Green" })
Write-Host "[!] Avertissements: $Warnings" -ForegroundColor Yellow
Write-Host ""

if ($Failed -eq 0) {
  Write-Host "[OK] Tous les tests critiques sont passes!" -ForegroundColor Green
  Write-Host ""
  Write-Host "Vous pouvez maintenant lancer: Build-All.cmd" -ForegroundColor Cyan
}
else {
  Write-Host "[XX] Certains tests critiques ont echoue. Veuillez corriger avant de continuer." -ForegroundColor Red
}

Write-Host ""
