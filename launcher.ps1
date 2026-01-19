#requires -Version 5.1
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Test-IsAdmin {
  return ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
  ).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Ensure-Dir([string]$p) {
  if (-not (Test-Path -LiteralPath $p)) {
    New-Item -ItemType Directory -Path $p -Force | Out-Null
  }
}

function Write-LauncherLog([string]$log,[string]$msg) {
  $ts = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
  try { Add-Content -Path $log -Value "[$ts] $msg" -Encoding UTF8 } catch {}
}

function Show-Err([string]$title,[string]$msg) {
  try {
    Add-Type -AssemblyName PresentationFramework -ErrorAction Stop
    [System.Windows.MessageBox]::Show($msg,$title,"OK","Error") | Out-Null
  } catch {
    # fallback console
    Write-Host "$title : $msg" -ForegroundColor Red
  }
}

# ----------------------------
# Root (portable folder)
# ----------------------------
$Root = Split-Path -Parent $PSCommandPath
Set-Location -LiteralPath $Root

# ----------------------------
# Logs
# ----------------------------
$logDir = Join-Path $Root "logs"
Ensure-Dir $logDir

$launcherLog = Join-Path $logDir ("launcher_{0}.log" -f (Get-Date -Format "yyyyMMdd_HHmmss"))
Write-LauncherLog $launcherLog "Launcher start"
Write-LauncherLog $launcherLog "Root=$Root"

# ----------------------------
# pwsh portable
# ----------------------------
$Pwsh = Join-Path $Root "pwsh\pwsh.exe"
if (-not (Test-Path -LiteralPath $Pwsh)) {
  $m = "pwsh.exe introuvable:`n$Pwsh"
  Write-LauncherLog $launcherLog "ERROR: $m"
  Show-Err "Danew USB Wizard" $m
  exit 1
}

# ----------------------------
# Main entrypoint (UI loader)
# ----------------------------
$Entry = Join-Path $Root "Start-DanewUsbWizard.ps1"
if (-not (Test-Path -LiteralPath $Entry)) {
  $m = "Entrypoint introuvable:`n$Entry`n`n(Attendu: Start-DanewUsbWizard.ps1 dans le dossier portable)"
  Write-LauncherLog $launcherLog "ERROR: $m"
  Show-Err "Danew USB Wizard" $m
  exit 1
}

# Paths passed to Start-DanewUsbWizard.ps1 (robuste)
$xamlPath    = Join-Path $Root "ui\DanewWizard.xaml"
$payloadRoot = Join-Path $Root "payload"
$workDir     = "C:\Temp\DanewWinPE"

# Log runtime (WPF/CLI)
$runLog = Join-Path $logDir ("run_{0}.log" -f (Get-Date -Format "yyyyMMdd_HHmmss"))

# Arguments for pwsh
# IMPORTANT: -STA pour WPF
$argList = @(
  "-NoLogo","-NoProfile","-ExecutionPolicy","Bypass",
  "-STA",
  "-File", $Entry,
  "-XamlPath", $xamlPath,
  "-PayloadRoot", $payloadRoot,
  "-WorkDir", $workDir,
  "-LogPath", $runLog
)

Write-LauncherLog $launcherLog ("Pwsh={0}" -f $Pwsh)
Write-LauncherLog $launcherLog ("Entry={0}" -f $Entry)
Write-LauncherLog $launcherLog ("Args={0}" -f ($argList -join " "))
Write-LauncherLog $launcherLog ("RunLog={0}" -f $runLog)

# ----------------------------
# Relaunch admin if needed
# ----------------------------
try {
  if (-not (Test-IsAdmin)) {
    Write-LauncherLog $launcherLog "Not admin => RunAs"
    Start-Process -FilePath $Pwsh -Verb RunAs -ArgumentList $argList -WorkingDirectory $Root | Out-Null
    exit 0
  }

  Write-LauncherLog $launcherLog "Admin => start"
  # NE PAS mettre -WindowStyle Hidden (sinon UI invisible)
  Start-Process -FilePath $Pwsh -ArgumentList $argList -WorkingDirectory $Root | Out-Null
  exit 0
}
catch {
  $m = $_.Exception.Message
  Write-LauncherLog $launcherLog "FATAL: $m"
  Show-Err "Danew USB Wizard" ("Erreur launcher:`n$m`n`nLog:`n$launcherLog")
  exit 1
}
