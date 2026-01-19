#requires -Version 5.1
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

param(
  [string]$XamlPath,
  [string]$PayloadRoot,
  [string]$WorkDir = "C:\Temp\DanewWinPE",
  [string]$LogPath,
  [int]   $DiskNumber,
  [switch]$Cli,
  [switch]$ValidateBootWimHash
)

function Initialize-Directory([string]$Path) {
  if ($Path -and -not (Test-Path -LiteralPath $Path)) {
    New-Item -ItemType Directory -Path $Path -Force | Out-Null
  }
}

function Test-IsAdmin {
  return ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
  ).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Write-Log([string]$msg) {
  $ts = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
  $line = "[$ts] $msg"
  Write-Host $line
  if ($script:LogPath) {
    try { Add-Content -Path $script:LogPath -Value $line -Encoding UTF8 } catch {}
  }
}

function Show-Err([string]$title,[string]$msg) {
  try {
    Add-Type -AssemblyName PresentationFramework -ErrorAction Stop
    [System.Windows.MessageBox]::Show($msg,$title,"OK","Error") | Out-Null
  } catch {
    Write-Host "$title : $msg" -ForegroundColor Red
  }
}

function Import-DanewWinPEModule([string]$baseDir) {
  $mod = Join-Path $baseDir "modules\Danew.WinPE.psm1"
  if (-not (Test-Path -LiteralPath $mod)) {
    throw "Module introuvable: $mod"
  }
  Import-Module $mod -Force
}

function Get-ProjectRoot() {
  # Si exécuté dans le portable, $PSScriptRoot est le root.
  return $PSScriptRoot
}

function Resolve-Defaults([string]$root) {
  if (-not $PayloadRoot) { $script:PayloadRoot = (Join-Path $root "payload") }
  if (-not $XamlPath)    { $script:XamlPath    = (Join-Path $root "ui\DanewWizard.xaml") }
  if (-not $LogPath)     {
    $logDir = Join-Path $root "logs"
    Ensure-Dir $logDir
    $script:LogPath = Join-Path $logDir ("run_{0}.log" -f (Get-Date -Format "yyyyMMdd_HHmmss"))
  }
  # Ensure log dir exists
  Ensure-Dir (Split-Path $script:LogPath -Parent)
}

function Start-TranscriptSafe() {
  try { Start-Transcript -Path $script:LogPath -Append | Out-Null } catch {}
}

function Stop-TranscriptSafe() {
  try { Stop-Transcript | Out-Null } catch {}
}

function Select-UsbDiskCli() {
  $candidates = Get-Disk | Where-Object {
    $_.BusType -eq "USB" -and $_.Size -gt 0 -and $_.OperationalStatus -eq "Online"
  } | Sort-Object Number

  Write-Log "Disques USB détectés:"
  $candidates | Format-Table Number,FriendlyName,BusType,Size,OperationalStatus | Out-String | ForEach-Object { Write-Log $_.TrimEnd() }

  if (-not $candidates) { throw "Aucun disque USB ONLINE détecté." }

  $n = Read-Host "DiskNumber USB à utiliser (ex: 2)"
  if ([string]::IsNullOrWhiteSpace($n)) { throw "DiskNumber vide." }
  return [int]$n
}

function Invoke-CreateUsb([int]$dn) {
  if (-not (Test-IsAdmin)) { throw "Admin requis (opérations DISKPART / WinPE)." }

  Write-Log "=== Create WinPE USB ==="
  Write-Log ("DiskNumber={0} PayloadRoot={1} WorkDir={2}" -f $dn,$script:PayloadRoot,$WorkDir)

  if (-not (Test-Path -LiteralPath $script:PayloadRoot)) { throw "PayloadRoot introuvable: $($script:PayloadRoot)" }
  Ensure-Dir $WorkDir

  # Appel de votre module
  New-DanewWinPEUsb -DiskNumber $dn -PayloadRoot $script:PayloadRoot -WorkDir $WorkDir `
    -ValidateBootWimHash:$ValidateBootWimHash `
    -LogPath $script:LogPath

  Write-Log "SUCCESS: clé WinPE créée."
}

function Start-CliMode() {
  Write-Log "Mode CLI"
  $dn = $DiskNumber
  if (-not $dn) { $dn = Select-UsbDiskCli }
  Invoke-CreateUsb -dn $dn
}

function Start-WpfMode() {
  # Préconditions WPF
  Add-Type -AssemblyName PresentationFramework
  Add-Type -AssemblyName PresentationCore
  Add-Type -AssemblyName WindowsBase

  if (-not (Test-Path -LiteralPath $script:XamlPath)) {
    throw "XAML introuvable: $($script:XamlPath)"
  }

  $xaml = Get-Content -LiteralPath $script:XamlPath -Raw
  $reader = New-Object System.Xml.XmlNodeReader ([xml]$xaml)
  $window = [Windows.Markup.XamlReader]::Load($reader)

  $status   = $window.FindName("StatusText")
  $progress = $window.FindName("Progress")
  $btn      = $window.FindName("StartBtn")

  if (-not $status -or -not $progress -or -not $btn) {
    throw "XAML incomplet: StatusText/Progress/StartBtn introuvables."
  }

  $status.Text = "Ready"
  $progress.IsIndeterminate = $false

  # BackgroundWorker pour ne pas freezer l'UI
  $bw = New-Object System.ComponentModel.BackgroundWorker
  $bw.WorkerReportsProgress = $true

  $bw.add_DoWork({
    param($bwSender,$e)

    $bwSender.ReportProgress(0, "Préparation…")

    $dn = $using:DiskNumber
    if (-not $dn) {
      # mini prompt en UI (fallback simple)
      $bwSender.ReportProgress(0, "DiskNumber requis (fallback console)…")
      $dn = Select-UsbDiskCli
    }

    $bwSender.ReportProgress(0, "Création WinPE USB sur Disk #$dn…")
    Run-CreateUsb -dn $dn
    $bwSender.ReportProgress(100, "Terminé.")
  })

  $bw.add_ProgressChanged({
    param($bwSender,$e)
    $msg = [string]$e.UserState
    if ($msg) { $status.Text = $msg }
    if ($e.ProgressPercentage -ge 0 -and $e.ProgressPercentage -le 100) {
      $progress.IsIndeterminate = $false
      $progress.Value = $e.ProgressPercentage
    } else {
      $progress.IsIndeterminate = $true
    }
  })

  $bw.add_RunWorkerCompleted({
    param($bwSender,$e)
    $btn.IsEnabled = $true
    $progress.IsIndeterminate = $false

    if ($e.Error) {
      $status.Text = "Erreur: " + $e.Error.Message
      Show-Err "Danew USB Wizard" ("Erreur:`n{0}`n`nLog:`n{1}" -f $e.Error.Message,$using:LogPath)
      return
    }

    $status.Text = "OK"
    try {
      [System.Windows.MessageBox]::Show("Clé WinPE créée avec succès.`n`nLog:`n$using:LogPath","Danew USB Wizard","OK","Information") | Out-Null
    } catch {}
  })

  $btn.add_Click({
    $btn.IsEnabled = $false
    $progress.IsIndeterminate = $true
    $status.Text = "Démarrage…"
    $bw.RunWorkerAsync() | Out-Null
  })

  $null = $window.ShowDialog()
}

# ========= MAIN =========
$root = Get-ProjectRoot
Resolve-Defaults -root $root

Start-TranscriptSafe
try {
  Write-Log "Start-DanewUsbWizard starting"
  Write-Log ("Root={0}" -f $root)
  Write-Log ("XamlPath={0}" -f $script:XamlPath)
  Write-Log ("PayloadRoot={0}" -f $script:PayloadRoot)
  Write-Log ("WorkDir={0}" -f $WorkDir)

  Import-DanewWinPEModule -baseDir $root

  if ($Cli) {
    Start-CliMode
    exit 0
  }

  try {
    Start-WpfMode
  } catch {
    Write-Log ("WPF FAILED => fallback CLI. Reason: {0}" -f $_.Exception.Message)
    Start-CliMode
  }
}
catch {
  Write-Log ("FATAL: {0}" -f $_.Exception.Message)
  Show-Err "Danew USB Wizard" ("Erreur fatale:`n{0}`n`nLog:`n{1}" -f $_.Exception.Message,$script:LogPath)
  throw
}
finally {
  Stop-TranscriptSafe
}
