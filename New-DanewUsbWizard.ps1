#requires -Version 7.0
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

function Test-IsAdmin {
  try {
    ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
    ).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
  } catch { $false }
}

function New-Directory([string]$Path) {
  if ($Path -and -not (Test-Path -LiteralPath $Path)) {
    New-Item -ItemType Directory -Path $Path -Force | Out-Null
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

function Show-Info([string]$title,[string]$msg) {
  try {
    Add-Type -AssemblyName PresentationFramework -ErrorAction Stop
    [System.Windows.MessageBox]::Show($msg,$title,"OK","Information") | Out-Null
  } catch {
    Write-Host "$title : $msg"
  }
}

function Write-Log([string]$path,[string]$msg) {
  $ts = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
  $line = "[$ts] $msg"
  Write-Host $line
  try { Add-Content -Path $path -Value $line -Encoding UTF8 } catch {}
}

# ---- Guards
if (-not (Test-IsAdmin)) {
  throw "Admin requis. Lance via launcher (RunAs) ou pwsh en administrateur."
}
if ([Threading.Thread]::CurrentThread.ApartmentState -ne 'STA') {
  throw "STA requis (WPF). Lance via: pwsh -STA -File .\New-DanewUsbWizard.ps1"
}

# ---- App root
$Root    = $PSScriptRoot
$Modules = Join-Path $Root "modules"
$Config  = Join-Path $Root "config.psd1"
$Payload = Join-Path $Root "payload"
$UiXaml  = Join-Path $Root "ui\DanewWizard.xaml"

if (-not (Test-Path -LiteralPath $Modules)) { throw "Dossier modules introuvable: $Modules" }
if (-not (Test-Path -LiteralPath $Config))  { throw "config.psd1 introuvable. Lance Init-DanewConfig.ps1 une fois." }
if (-not (Test-Path -LiteralPath $Payload)) { throw "Dossier payload introuvable: $Payload" }
if (-not (Test-Path -LiteralPath $UiXaml))  { throw "XAML introuvable: $UiXaml" }

# ---- Modules
Get-Module Danew.* | Remove-Module -Force -ErrorAction SilentlyContinue
Import-Module (Join-Path $Modules "Danew.Common.psm1") -Force -ErrorAction Stop
Import-Module (Join-Path $Modules "Danew.Disk.psm1")   -Force -ErrorAction Stop
Import-Module (Join-Path $Modules "Danew.WinPE.psm1")  -Force -ErrorAction Stop

# ---- Config
$cfg = Import-PowerShellDataFile -Path $Config
$cfg.Arch         ??= "amd64"
$cfg.WorkDir      ??= "C:\Temp\DanewWinPE"
$cfg.MinUsbSizeGB ??= 7
$cfg.LogRoot      ??= "C:\Temp\WinPE_OneClick_Logs"
$cfg.AppTitle     ??= "Danew USB Wizard - Create WinPE USB (SAV)"
$cfg.PayloadRoot  ??= "payload"

$cfg.WorkDir = [IO.Path]::GetFullPath($cfg.WorkDir)
$cfg.LogRoot = [IO.Path]::GetFullPath($cfg.LogRoot)

if (-not [IO.Path]::IsPathRooted($cfg.PayloadRoot)) {
  $cfg.PayloadRoot = Join-Path $Root $cfg.PayloadRoot
}
$cfg.PayloadRoot = [IO.Path]::GetFullPath($cfg.PayloadRoot)

New-Directory $cfg.LogRoot
$LogPath = Join-Path $cfg.LogRoot ("CreateUsb_{0}.log" -f (Get-Date -Format "yyyyMMdd_HHmmss"))

# ---- WPF
Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase

# Load XAML
try {
  $xaml = Get-Content -LiteralPath $UiXaml -Raw
  $reader = New-Object System.Xml.XmlNodeReader ([xml]$xaml)
  $Window = [Windows.Markup.XamlReader]::Load($reader)
  Write-Log $LogPath "XAML loaded successfully"
} catch {
  throw "Impossible de charger le XAML: $UiXaml | $($_.Exception.Message)"
}

# Bind controls
$StatusText = $Window.FindName("StatusText")
$ProgressOverall = $Window.FindName("ProgressOverall")
$ProgressPercent = $Window.FindName("ProgressPercent")
$StepsPanel = $Window.FindName("StepsPanel")
$DiskComboBox = $Window.FindName("DiskComboBox")
$StartBtn = $Window.FindName("StartBtn")
$CancelBtn = $Window.FindName("CancelBtn")
$StatusBorder = $Window.FindName("StatusBorder")
$FinalStatus = $Window.FindName("FinalStatus")
$FinalDetails = $Window.FindName("FinalDetails")

if (-not $ProgressOverall -or -not $StartBtn -or -not $DiskComboBox) {
  throw "XAML incomplet: contrôles manquants."
}

$Window.Title = [string]$cfg.AppTitle
$Window.Topmost = $true

Write-Log $LogPath "=== Danew USB Wizard UI ==="
Write-Log $LogPath ("Root={0}" -f $Root)
Write-Log $LogPath ("PayloadRoot={0}" -f $cfg.PayloadRoot)
Write-Log $LogPath ("WorkDir={0}" -f $cfg.WorkDir)
Write-Log $LogPath ("MinUsbSizeGB={0}" -f $cfg.MinUsbSizeGB)

# ---- Define USB candidate functions
function Get-UsbCandidates {
  Get-Disk | Where-Object {
    $_.BusType -eq "USB" -and $_.Size -gt 0 -and $_.OperationalStatus -eq "Online"
  } | Sort-Object Number
}

function Select-UsbDiskNumber {
  $c = @(Get-UsbCandidates)
  if (-not $c) { throw "Aucun disque USB ONLINE détecté." }

  # Filter by size
  $minBytes = [int64]$cfg.MinUsbSizeGB * 1GB
  $c2 = @($c | Where-Object { $_.Size -ge $minBytes })
  if (-not $c2) {
    $sizes = ($c | ForEach-Object { "#$($_.Number) $($_.FriendlyName) $([Math]::Round($_.Size/1GB,1))GB" }) -join "`n"
    throw "Aucun USB >= $($cfg.MinUsbSizeGB)GB.`nDisques vus:`n$sizes"
  }

  if ($c2.Count -eq 1) { return [int]$c2[0].Number }

  # If multiple, auto-pick the smallest suitable one (less risk)
  $pick = $c2 | Sort-Object Size | Select-Object -First 1
  $list = ($c2 | ForEach-Object { "#$($_.Number)  $($_.FriendlyName)  $([Math]::Round($_.Size/1GB,1))GB" }) -join "`n"
  Write-Host "`nDisques USB candidats:`n$list`n"
  Write-Host "Auto-selection: Disk #$($pick.Number) - $($pick.FriendlyName)"
  Write-Log $LogPath ("Auto-selected: Disk #$($pick.Number) (smallest suitable USB >= $($cfg.MinUsbSizeGB)GB)")
  return [int]$pick.Number
}

# Populate disk combo box
function Populate-DiskComboBox {
  $candidates = Get-UsbCandidates
  $minBytes = [int64]$cfg.MinUsbSizeGB * 1GB
  $suitable = @($candidates | Where-Object { $_.Size -ge $minBytes })
  
  $DiskComboBox.Items.Clear()
  foreach ($disk in $suitable) {
    $label = "#$($disk.Number) - $($disk.FriendlyName) ($([Math]::Round($disk.Size/1GB,1))GB)"
    $item = New-Object System.Windows.Controls.ComboBoxItem
    $item.Content = $label
    $item.Tag = $disk.Number
    $DiskComboBox.Items.Add($item) | Out-Null
  }
  
  if ($DiskComboBox.Items.Count -gt 0) {
    $DiskComboBox.SelectedIndex = 0  # Auto-select first
  }
  
  Write-Log $LogPath "Disk combo populated with $($DiskComboBox.Items.Count) disk(s)"
}

Populate-DiskComboBox

# Helper function to add step to UI
function Add-StepToUI {
  param([string]$StepName, [string]$Status = "Pending")
  
  $statusColors = @{
    "Pending" = "#95A5A6"
    "Running" = "#F39C12"
    "Success" = "#27AE60"
    "Error" = "#E74C3C"
  }
  
  $statusSymbols = @{
    "Pending" = "○"
    "Running" = "⟳"
    "Success" = "✓"
    "Error" = "✕"
  }
  
  $step = New-Object System.Windows.Controls.TextBlock
  $step.Text = "$($statusSymbols[$Status]) $StepName"
  $step.FontSize = 11
  $step.Foreground = New-Object System.Windows.Media.SolidColorBrush([System.Windows.Media.ColorConverter]::ConvertFromString($statusColors[$Status]))
  $step.Margin = New-Object System.Windows.Thickness(0, 5, 0, 0)
  $step.Tag = $StepName
  
  $StepsPanel.Children.Add($step) | Out-Null
}

function Update-StepStatus {
  param([string]$StepName, [string]$NewStatus)
  
  $statusColors = @{
    "Pending" = "#95A5A6"
    "Running" = "#F39C12"
    "Success" = "#27AE60"
    "Error" = "#E74C3C"
  }
  
  $statusSymbols = @{
    "Pending" = "○"
    "Running" = "⟳"
    "Success" = "✓"
    "Error" = "✕"
  }
  
  foreach ($child in $StepsPanel.Children) {
    if ($child.Tag -eq $StepName) {
      $child.Text = "$($statusSymbols[$NewStatus]) $StepName"
      $child.Foreground = New-Object System.Windows.Media.SolidColorBrush([System.Windows.Media.ColorConverter]::ConvertFromString($statusColors[$NewStatus]))
      break
    }
  }
}

function Update-Progress {
  param([int]$Percent, [string]$Message = "")
  $ProgressOverall.Value = $Percent
  $ProgressPercent.Text = "$Percent%"
  if ($Message) {
    $StatusText.Text = $Message
  }
}

# Clear initial steps and populate with main steps
$StepsPanel.Children.Clear()
Add-StepToUI "USB Disk Detection" "Pending"
Add-StepToUI "Format and Partition" "Pending"
Add-StepToUI "WinPE Environment" "Pending"
Add-StepToUI "UEFI Files" "Pending"
Add-StepToUI "Payload Copy" "Pending"
Add-StepToUI "Finalization" "Pending"

Update-Progress 0 "Ready to create WinPE USB"

# ---- Button handlers

# Button handlers
$CancelBtn.add_Click({
  Write-Log $LogPath "Cancel button clicked"
  $Window.Close()
})

# Start button handler - get selected disk from combo box
$StartBtn.add_Click({
  param($UIElement, $EventArgs)
  
  if ($DiskComboBox.SelectedItem -eq $null) {
    [Windows.MessageBox]::Show("Please select a USB disk", "Danew USB Wizard", "OK", "Warning") | Out-Null
    return
  }
  
  $selectedDN = $DiskComboBox.SelectedItem.Tag
  
  $StartBtn.IsEnabled = $false
  $DiskComboBox.IsEnabled = $false
  $CancelBtn.IsEnabled = $false
  
  try {
    Write-Log $LogPath "Button clicked -> starting USB creation for Disk #$selectedDN"
    
    # AGGRESSIVE CLEANUP v3: Force-clean WorkDir before starting
    Write-Log $LogPath ">>> AGGRESSIVE CLEANUP: Removing $($cfg.WorkDir)..."
    if (Test-Path -LiteralPath $cfg.WorkDir) {
      try {
        Remove-Item -LiteralPath $cfg.WorkDir -Recurse -Force -ErrorAction Stop
        Write-Log $LogPath "    ✓ WorkDir removed successfully"
      } catch {
        Write-Log $LogPath "    WARN: Failed to remove WorkDir: $_"
      }
    }
    Start-Sleep -Seconds 1
    
    Update-StepStatus "USB Disk Detection" "Running"
    Update-Progress 5 "Detecting USB disk #$selectedDN..."
    
    Start-Sleep -Milliseconds 500
    
    Update-StepStatus "USB Disk Detection" "Success"
    Update-Progress 15 "Formatting and partitioning..."
    Update-StepStatus "Format and Partition" "Running"
    
    # === REAL ACTION ===
    New-DanewWinPEUsb -DiskNumber $selectedDN -PayloadRoot $cfg.PayloadRoot -WorkDir $cfg.WorkDir -LogPath $LogPath `
      -OnLog { param($msg) Write-Log $LogPath $msg } `
      -OnProgress { 
        param($percent, $msg)
        Update-Progress $percent $msg
      }
    
    Update-StepStatus "Format and Partition" "Success"
    Update-StepStatus "WinPE Environment" "Success"
    Update-StepStatus "UEFI Files" "Success"
    Update-StepStatus "Payload Copy" "Success"
    Update-StepStatus "Finalization" "Success"
    
    Update-Progress 100 "Complete!"
    
    Write-Log $LogPath "SUCCESS"
    
    # Show success message
    $StatusBorder.Visibility = [System.Windows.Visibility]::Visible
    $FinalStatus.Text = "✓ WinPE USB Created Successfully!"
    $FinalStatus.Foreground = New-Object System.Windows.Media.SolidColorBrush([System.Windows.Media.ColorConverter]::ConvertFromString("#27AE60"))
    $FinalDetails.Text = "The USB drive is ready for deployment.`nDisk #$selectedDN has been successfully formatted with WinPE."
    
    Start-Sleep -Seconds 2
    
    [Windows.MessageBox]::Show("WinPE USB created successfully!`n`nDisk #$selectedDN is ready for deployment.", "Success", "OK", "Information") | Out-Null
    
  } catch {
    Update-StepStatus "Format and Partition" "Error"
    Write-Log $LogPath ("ERROR: {0}" -f $_.Exception.Message)
    Write-Log $LogPath ("StackTrace: {0}" -f $_.Exception.StackTrace)
    
    # Show error message
    $StatusBorder.Visibility = [System.Windows.Visibility]::Visible
    $FinalStatus.Text = "✕ Error Creating WinPE USB"
    $FinalStatus.Foreground = New-Object System.Windows.Media.SolidColorBrush([System.Windows.Media.ColorConverter]::ConvertFromString("#E74C3C"))
    $FinalDetails.Text = "Error: $($_.Exception.Message)`n`nCheck the log file for details."
    
    [Windows.MessageBox]::Show("Error: $($_.Exception.Message)`n`nLog: $LogPath", "Error", "OK", "Error") | Out-Null
    
  } finally {
    $StartBtn.IsEnabled = $true
    $DiskComboBox.IsEnabled = $false  # Keep disabled after operation
    $CancelBtn.IsEnabled = $true
  }
})

# Ready
$ProgressOverall.IsIndeterminate = $false
$ProgressOverall.Value = 0
$StatusText.Text = "Ready"
Write-Log $LogPath "UI Ready"
Write-Log $LogPath "Showing window..."

# Show window
$result = $Window.ShowDialog()
Write-Log $LogPath "Window closed with result: $result"
