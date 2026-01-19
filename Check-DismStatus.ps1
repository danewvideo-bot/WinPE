#!/usr/bin/pwsh
#requires -RunAsAdministrator

<#
DISM Mount Status Check - Debug Script
========================================
Checks for orphaned WIM mounts and cleans them up
#>

Write-Host "`n╔════════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║         DISM MOUNT STATUS AND CLEANUP CHECKER                ║" -ForegroundColor Cyan
Write-Host "╚════════════════════════════════════════════════════════════════╝`n" -ForegroundColor Cyan

$dism = "C:\WINDOWS\System32\dism.exe"

# Check current mounts
Write-Host "1️⃣ Checking current DISM mount status..." -ForegroundColor Yellow
try {
    $output = & $dism /Get-MountPoints 2>&1
    if ($output -match "No mounts" -or $output.Count -eq 0) {
        Write-Host "   ✅ No mounts found (clean state)" -ForegroundColor Green
    } else {
        Write-Host "   ⚠️  Found mounts:" -ForegroundColor Yellow
        $output | ForEach-Object { Write-Host "      $_" -ForegroundColor Yellow }
    }
} catch {
    Write-Host "   Note: Got error (need admin): $_" -ForegroundColor Gray
}

# Clean up
Write-Host "`n2️⃣ Executing DISM /Cleanup-Mountpoints..." -ForegroundColor Yellow
try {
    $output = & $dism /Cleanup-Mountpoints 2>&1
    Write-Host "   ✓ Cleanup executed" -ForegroundColor Green
    if ($output) { Write-Host "   Output: $($output | Select-Object -First 3)" -ForegroundColor Gray }
} catch {
    Write-Host "   ✗ Error: $_" -ForegroundColor Red
}

# Double-check
Write-Host "`n3️⃣ Final verification..." -ForegroundColor Yellow
Start-Sleep -Seconds 1
try {
    $output = & $dism /Get-MountPoints 2>&1
    if ($output -match "No mounts" -or $output.Count -eq 0) {
        Write-Host "   ✅ DISM state is clean!" -ForegroundColor Green
    } else {
        Write-Host "   ⚠️  Mounts still exist:" -ForegroundColor Yellow
        $output | ForEach-Object { Write-Host "      $_" -ForegroundColor Yellow }
    }
} catch {
    Write-Host "   Note: Error during check: $_" -ForegroundColor Gray
}

# Check directories
Write-Host "`n4️⃣ Checking WorkDir..." -ForegroundColor Yellow
$workdir = "C:\Temp\DanewWinPE"
if (Test-Path $workdir) {
    Write-Host "   ⚠️  WorkDir exists: $workdir" -ForegroundColor Yellow
    Write-Host "   Removing..." -ForegroundColor Yellow
    try {
        Remove-Item -LiteralPath $workdir -Recurse -Force
        Write-Host "   ✅ WorkDir removed" -ForegroundColor Green
    } catch {
        Write-Host "   ✗ Failed to remove: $_" -ForegroundColor Red
    }
} else {
    Write-Host "   ✅ WorkDir doesn't exist (clean)" -ForegroundColor Green
}

Write-Host "`n════════════════════════════════════════════════════════════════`n" -ForegroundColor Cyan
Write-Host "✅ Cleanup check complete. Ready to run Build-All.cmd`n" -ForegroundColor Green
