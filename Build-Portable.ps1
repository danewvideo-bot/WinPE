param(
  [switch]$Force,
  [switch]$BuildExe,
  [switch]$OnlyExe
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

function Write-Info($m) { Write-Host ("[INFO] " + $m) }
function Write-Warn($m) { Write-Host ("[WARN] " + $m) -ForegroundColor Yellow }
function Write-Ok($m)   { Write-Host ("[OK] " + $m) -ForegroundColor Green }

function Get-ScriptRoot {
  if ($PSScriptRoot) { return $PSScriptRoot }
  if ($PSCommandPath) { return (Split-Path -Parent $PSCommandPath) }
  $p = $MyInvocation.MyCommand.Path
  if ($p) { return (Split-Path -Parent $p) }
  return (Get-Location).Path
}

function Ensure-Dir([string]$p) {
  if (-not (Test-Path -LiteralPath $p)) {
    New-Item -ItemType Directory -Path $p -Force | Out-Null
  }
}

function Copy-Tree([string]$src, [string]$dst) {
  if (-not (Test-Path -LiteralPath $src)) { throw "Source missing: $src" }
  Ensure-Dir $dst
  $items = @(Get-ChildItem -LiteralPath $src -Force)
  foreach ($it in $items) {
    Copy-Item -LiteralPath $it.FullName -Destination (Join-Path $dst $it.Name) -Recurse -Force
  }
}

function Make-FilenameSafe([string]$s) {
  if (-not $s) { return "dev" }
  $t = $s -replace '\+','_'
  $t = $t -replace '[^0-9A-Za-z\.\-_]','_'
  return $t
}

# -------------------------------------------------
# Version tag
# -------------------------------------------------
$root = Get-ScriptRoot
$version =
  if ($env:DANEW_VERSION -and $env:DANEW_VERSION.Trim()) {
    $env:DANEW_VERSION.Trim()
  } elseif (Test-Path -LiteralPath (Join-Path $root "VERSION")) {
    (Get-Content (Join-Path $root "VERSION") -Raw).Trim()
  } else {
    "dev"
  }

$tag = $version
if (-not $tag -or $tag -eq "dev") {
  $tag = (Get-Date -Format "yyyyMMdd_HHmmss")
}
$tagSafe = Make-FilenameSafe $tag

Write-Info "Portable tag: $tagSafe (version=$version)"

# -------------------------------------------------
# Inputs
# -------------------------------------------------
$srcStart    = Join-Path $root "Start-DanewUsbWizard.ps1"
$srcNew      = Join-Path $root "New-DanewUsbWizard.ps1"
$srcConfig   = Join-Path $root "config.psd1"
$srcLauncher = Join-Path $root "launcher.ps1"      # OPTIONAL mais recommandé
$srcUiDir    = Join-Path $root "ui"                # NEW
$srcXaml     = Join-Path $srcUiDir "DanewWizard.xaml"

$srcModules  = Join-Path $root "modules"
$srcPayload  = Join-Path $root "payload"

$srcPwsh     = Join-Path $root "pwsh"              # optional
$srcIcon     = Join-Path $root "danew.ico"         # optional

foreach($p in @($srcStart,$srcNew,$srcConfig,$srcModules,$srcPayload)){
  if (-not (Test-Path -LiteralPath $p)) { throw "Fichier/dossier introuvable: $p" }
}

# XAML requis pour WPF
if (-not (Test-Path -LiteralPath $srcXaml)) {
  throw "UI manquante: $srcXaml (crée ui\DanewWizard.xaml ou adapte le chemin)"
}

# -------------------------------------------------
# Outputs
# -------------------------------------------------
$dist = Join-Path $root "dist"
Ensure-Dir $dist

$outDir = Join-Path $dist ("DanewUsbWizard_Portable_{0}" -f $tagSafe)
$outZip = Join-Path $dist ("DanewUsbWizard_Portable_{0}.zip" -f $tagSafe)
$outExe = Join-Path $dist ("DanewUsbWizard_{0}.exe" -f $tagSafe)

$runCmdNameVersioned = ("RunDanewUsbWizard_{0}.cmd" -f $tagSafe)
$runCmdNameStable = "RunDanewUsbWizard.cmd"

# -------------------------------------------------
# Build portable folder + ZIP (unless OnlyExe)
# -------------------------------------------------
if (-not $OnlyExe) {

  if (Test-Path -LiteralPath $outDir) {
    if ($Force) { Remove-Item -LiteralPath $outDir -Recurse -Force }
    else { throw "Le dossier existe déjà: $outDir (utilise -Force)" }
  }
  if (Test-Path -LiteralPath $outZip) {
    if ($Force) { Remove-Item -LiteralPath $outZip -Force }
    else { throw "Le ZIP existe déjà: $outZip (utilise -Force)" }
  }

  Write-Info "Build portable folder"
  Ensure-Dir $outDir

  Write-Info "Copy scripts/config"
  Copy-Item -LiteralPath $srcStart  -Destination (Join-Path $outDir "Start-DanewUsbWizard.ps1") -Force
  Copy-Item -LiteralPath $srcNew    -Destination (Join-Path $outDir "New-DanewUsbWizard.ps1")   -Force
  Copy-Item -LiteralPath $srcConfig -Destination (Join-Path $outDir "config.psd1")              -Force

  if (Test-Path -LiteralPath $srcLauncher) {
    Copy-Item -LiteralPath $srcLauncher -Destination (Join-Path $outDir "launcher.ps1") -Force
  } else {
    Write-Warn "launcher.ps1 absent: l'EXE double-clic sera moins robuste."
  }

  Write-Info "Copy UI (XAML)"
  Ensure-Dir (Join-Path $outDir "ui")
  Copy-Tree $srcUiDir (Join-Path $outDir "ui")

  Write-Info "Copy modules + payload"
  Ensure-Dir (Join-Path $outDir "modules")
  Ensure-Dir (Join-Path $outDir "payload")
  Copy-Tree $srcModules (Join-Path $outDir "modules")
  Copy-Tree $srcPayload (Join-Path $outDir "payload")

  # VERSION inside portable
  $version | Set-Content -Path (Join-Path $outDir "VERSION") -Encoding UTF8

  # Optional: pwsh portable
  if (Test-Path -LiteralPath $srcPwsh) {
    Write-Info "Copy pwsh portable"
    Ensure-Dir (Join-Path $outDir "pwsh")
    Copy-Tree $srcPwsh (Join-Path $outDir "pwsh")
  } else {
    Write-Warn "pwsh\ absent: nécessitera pwsh installé sur le PC"
  }

  # Optional: icon
  $iconInOut = $null
  if (Test-Path -LiteralPath $srcIcon) {
    $iconInOut = Join-Path $outDir "danew.ico"
    Copy-Item -LiteralPath $srcIcon -Destination $iconInOut -Force
    Write-Info "Icon copied: danew.ico"
  } else {
    Write-Warn "danew.ico introuvable à la racine (skip)"
  }

  # -------------------------------------------------
  # Create CMD launcher(s)
  # -------------------------------------------------
  Write-Info "Create CMD launcher(s)"

  # CMD: appelle launcher.ps1 si présent, sinon Start-DanewUsbWizard.ps1
  $cmdBody = @"
@echo off
setlocal
cd /d "%~dp0"

set "ENTRY=%~dp0launcher.ps1"
if not exist "%ENTRY%" set "ENTRY=%~dp0Start-DanewUsbWizard.ps1"

REM Prefer bundled pwsh if present
if exist "%~dp0pwsh\pwsh.exe" (
  "%~dp0pwsh\pwsh.exe" -NoProfile -ExecutionPolicy Bypass -STA -File "%ENTRY%"
) else (
  pwsh.exe -NoProfile -ExecutionPolicy Bypass -STA -File "%ENTRY%"
)
"@

  $runCmdVersioned = Join-Path $outDir $runCmdNameVersioned
  $cmdBody | Set-Content -Path $runCmdVersioned -Encoding ASCII

  $runCmdStable = Join-Path $outDir $runCmdNameStable
  $cmdBody | Set-Content -Path $runCmdStable -Encoding ASCII

  # Shortcut (.lnk) with icon
  if ($iconInOut) {
    try {
      $lnkPath = Join-Path $outDir ("Danew USB Wizard ({0}).lnk" -f $tagSafe)
      $wsh = New-Object -ComObject WScript.Shell
      $sc = $wsh.CreateShortcut($lnkPath)
      $sc.TargetPath = $runCmdStable
      $sc.WorkingDirectory = $outDir
      $sc.IconLocation = $iconInOut
      $sc.Save()
      Write-Info "Shortcut created: $(Split-Path -Leaf $lnkPath)"
    } catch {
      Write-Warn ("Shortcut creation failed: " + $_.Exception.Message)
    }
  }

  # -------------------------------------------------
  # ZIP
  # -------------------------------------------------
  Write-Info "Create ZIP"
  Compress-Archive -Path (Join-Path $outDir "*") -DestinationPath $outZip -Force

  Write-Ok "Portable folder + ZIP ready"
  Write-Host ("Folder: " + $outDir)
  Write-Host ("ZIP:    " + $outZip)
  Write-Host ("CMD v.:  " + (Join-Path $outDir $runCmdNameVersioned))
  Write-Host ("CMD:     " + (Join-Path $outDir $runCmdNameStable))
}

# -------------------------------------------------
# Build EXE (optional)
# -------------------------------------------------
if ($BuildExe) {
  Write-Info "Build EXE"

  $ps2exeCmd = Get-Command Invoke-PS2EXE -ErrorAction SilentlyContinue
  if (-not $ps2exeCmd) { $ps2exeCmd = Get-Command ps2exe -ErrorAction SilentlyContinue }

  if (-not $ps2exeCmd) {
    Write-Warn "PS2EXE introuvable (Invoke-PS2EXE/ps2exe) – EXE ignoré."
  } else {

    if (Test-Path -LiteralPath $outExe) {
      if ($Force) { Remove-Item -LiteralPath $outExe -Force }
      else { throw "EXE existe déjà: $outExe (utilise -Force)" }
    }

    $iconArg = $null
    if (Test-Path -LiteralPath $srcIcon) { $iconArg = (Resolve-Path $srcIcon).Path }

    # IMPORTANT: compile le LAUNCHER si présent, sinon Start
    $input = if (Test-Path -LiteralPath $srcLauncher) { $srcLauncher } else { $srcStart }

    try {
      if ($ps2exeCmd.Name -eq "Invoke-PS2EXE") {
        $p = (Get-Command Invoke-PS2EXE).Parameters
        if ($iconArg -and $p.ContainsKey("IconFile")) {
          Invoke-PS2EXE -InputFile $input -OutputFile $outExe -IconFile $iconArg -NoConsole:$false | Out-Null
        } else {
          Invoke-PS2EXE -InputFile $input -OutputFile $outExe -NoConsole:$false | Out-Null
        }
      } else {
        ps2exe $input $outExe | Out-Null
      }
      Write-Ok "EXE generated: $outExe (Input=$input)"
    } catch {
      Write-Warn ("Compilation EXE échouée: " + $_.Exception.Message)
    }
  }
}

Write-Ok "Build-Portable terminé"
