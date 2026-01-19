#requires -Version 5.1

param(
    [switch]$Force
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# =========================================================
# Paths
# =========================================================
$Root   = Split-Path -Parent $PSCommandPath
$Config = Join-Path $Root "config.psd1"

# =========================================================
# Protection écrasement
# =========================================================
if (Test-Path -LiteralPath $Config) {
    if (-not $Force) {
        throw "config.psd1 existe déjà. Relance avec -Force pour écraser."
    }
}

# =========================================================
# Contenu config.psd1
# =========================================================
$configContent = @"
@{
    Arch         = 'amd64'
    WorkDir      = 'C:\Temp\DanewWinPE'
    MinUsbSizeGB = 7
    LogRoot      = 'C:\Temp\WinPE_OneClick_Logs'
    AppTitle     = 'Danew USB Wizard - Create WinPE USB (SAV)'
    PayloadRoot  = 'payload'
}
"@

# =========================================================
# Écriture
# =========================================================
$configContent | Set-Content -Path $Config -Encoding UTF8 -Force

Write-Host "OK: config.psd1 créé → $Config" -ForegroundColor Green
