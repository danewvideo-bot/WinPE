# SelfTest.ps1 - Danew USB Wizard integration test (SAFE)
# Place this file in: payload\SelfTest.ps1
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Say([string]$msg, [string]$color = "White") {
    try { Write-Host $msg -ForegroundColor $color } catch { Write-Host $msg }
}

function Try-Run([string]$title, [scriptblock]$action) {
    Say ""
    Say ("== {0} ==" -f $title) Cyan
    try {
        & $action
        Say ("OK  {0}" -f $title) Green
        return $true
    } catch {
        Say ("ERR {0}: {1}" -f $title, $_.Exception.Message) Red
        return $false
    }
}

Say "=== Danew USB Wizard - SelfTest (SAFE / WhatIf) ===" Cyan
Say ("Time: {0}" -f (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")) DarkGray
Say ""

$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$modules = Join-Path $root "modules"

# 1) Check payload structure
$ok = $true
$ok = $ok -and (Try-Run "Check payload root" { if (-not (Test-Path $root)) { throw "Root not found: $root" } })
$ok = $ok -and (Try-Run "Check modules folder" { if (-not (Test-Path $modules)) { throw "Modules folder not found: $modules" } })

$required = @("Danew.Common.psm1","Danew.EFI.psm1","Danew.SystemRepair.psm1")
foreach ($f in $required) {
    $p = Join-Path $modules $f
    $ok = $ok -and (Try-Run "Check file $f" { if (-not (Test-Path $p)) { throw "Missing: $p" } })
}

# 2) Import modules
$common = Join-Path $modules "Danew.Common.psm1"
$efi    = Join-Path $modules "Danew.EFI.psm1"
$sys    = Join-Path $modules "Danew.SystemRepair.psm1"

$ok = $ok -and (Try-Run "Import Danew.Common"      { Import-Module $common -Force })
$ok = $ok -and (Try-Run "Import Danew.EFI"         { Import-Module $efi    -Force })
$ok = $ok -and (Try-Run "Import Danew.SystemRepair"{ Import-Module $sys    -Force })

# 3) Check required commands
$requiredCmds = @(
    "Initialize-DanewSession",
    "Write-DanewLog",
    "Export-DanewReport",
    "Invoke-DanewEFIRepair",
    "Invoke-DanewBootRepairAuto"
)

foreach ($c in $requiredCmds) {
    $ok = $ok -and (Try-Run "Get-Command $c" {
        if (-not (Get-Command $c -ErrorAction SilentlyContinue)) { throw "Command not found: $c" }
    })
}

# 4) Capability probes (informative only)
Try-Run "Capability: Get-Partition (informative)" {
    if (Get-Command Get-Partition -ErrorAction SilentlyContinue) {
        Say "Get-Partition available (WinPE Storage cmdlets present)." Green
    } else {
        Say "Get-Partition NOT available (WinPE minimal). This is OK if EFI module doesn't require it." Yellow
    }
} | Out-Null

Try-Run "Capability: bcdboot.exe (informative)" {
    $b = Get-Command bcdboot.exe -ErrorAction SilentlyContinue
    if ($b) { Say ("bcdboot.exe: {0}" -f $b.Source) Green }
    else    { Say "bcdboot.exe not found in PATH (rare in WinPE)." Yellow }
} | Out-Null

# 5) Initialize logs (best effort)
$logRoot = if (Test-Path "X:\") { "X:\Danew\Logs" } else { Join-Path $root "Logs" }
$session = $null

$ok = $ok -and (Try-Run "Initialize-DanewSession" {
    $session = Initialize-DanewSession -ForcePath $logRoot -Prefix "SelfTest"
    if (-not $session.LogFile) { throw "No LogFile returned" }
    Say ("LogRoot: {0}" -f $session.LogRoot) DarkGray
    Say ("LogFile: {0}" -f $session.LogFile) DarkGray
})

# 6) EFI repair DRY-RUN (SAFE)
$ok = $ok -and (Try-Run "Invoke-DanewBootRepairAuto -WhatIf (SAFE)" {
    Write-DanewLog -Level INFO -Message "SelfTest: starting EFI repair WhatIf"
    $r = Invoke-DanewBootRepairAuto -WhatIf
    Write-DanewLog -Level INFO -Message "SelfTest: EFI repair WhatIf completed" -Data @{ result = $r }
    Say "EFI repair WhatIf executed (no disk changes)." Green
})

# 7) Export report (optional)
Try-Run "Export-DanewReport (optional)" {
    $rep = Export-DanewReport -Name "SelfTest" -Summary @{ result = $(if($ok){"ok"}else{"error"}) }
    Say ("Report JSON: {0}" -f $rep.Json) DarkGray
    Say ("Report TXT : {0}" -f $rep.Txt) DarkGray
} | Out-Null

Say ""
if ($ok) {
    Say "=== SelfTest RESULT: OK ===" Cyan
    exit 0
} else {
    Say "=== SelfTest RESULT: ERROR (see logs/report) ===" Red
    exit 1
}
