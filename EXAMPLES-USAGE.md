# EXEMPLES D'UTILISATION - Danew USB Wizard

Exemples pratiques pour utiliser les nouveaux modules Danew.Diagnostic et Danew.Backup

## 1. DIAGNOSTIC AUTOMATISÉ

### Diagnostic Rapide (CLI)

```powershell
# Importer le module
Import-Module .\modules\Danew.Diagnostic.psm1 -Force

# Lancer diagnostic
$results = Invoke-DanewDiagnostic -RootPath "C:\DanewUsbWizard"
```

**Sortie attendue:**
```
╔════════════════════════════════════════════════════════════════╗
║  DIAGNOSTIC DANEW USB WIZARD - 2026-01-19 14:30:45  ║
╚════════════════════════════════════════════════════════════════╝

RÉSULTATS:
──────────────────────────────────────────────────────────────
✓ Admin Rights : ✓ Admin
✓ PowerShell Version : Current: 7.5.4 (requis 7.0+ pour CLI)
✓ Key Files : ✓ All files found
✓ Danew Modules : All 7 modules OK
✓ Config Files : ✓ JSON and POSH configs valid
✗ Windows ADK : ✗ Not found (required for WinPE build)
✓ Disk Space : Available: 145.32GB (required: 5GB)
! USB Availability : ✗ No USB disk found (>= 7GB, non-system)

──────────────────────────────────────────────────────────────
Résumé: 7/9 tests réussis
```

### Diagnostic Mode UI (avec STA)

```powershell
# Lancer PowerShell en mode STA (requis pour WPF)
powershell -STA -Command {
  Import-Module .\modules\Danew.Diagnostic.psm1 -Force
  Invoke-DanewDiagnostic -RootPath "C:\DanewUsbWizard" -Mode "UI"
}
```

### Diagnostic Personnalisé

```powershell
# Avec paramètres personnalisés
$results = Invoke-DanewDiagnostic `
  -RootPath "C:\DanewUsbWizard" `
  -Mode "CLI" `
  -MinDiskSpaceGB 10 `
  -MinUsbSizeGB 16

# Afficher seulement les tests échoués
$results | Where-Object { -not $_.Passed } | Format-Table
```

### Tests Individuels

```powershell
Import-Module .\modules\Danew.Diagnostic.psm1 -Force

# Tester admin
Test-AdminRights

# Tester PowerShell
Test-PowerShellVersion -Mode "UI"

# Tester modules
Test-DanewModules -ModulesPath ".\modules"

# Tester Windows ADK
Test-WindowsAdk

# Tester espace disque
Test-DiskSpace -MinGBRequired 5 -CheckPath "C:\"

# Tester USB
Test-UsbAvailability -MinGBRequired 7
```

---

## 2. SAUVEGARDE & RESTAURATION

### Exporter une Image Système

#### Cas 1: Export Simple

```powershell
Import-Module .\modules\Danew.Backup.psm1 -Force

# Exporter C: vers USB X:
$backup = Export-SystemImage `
  -SourceDrive "C:" `
  -OutputPath "X:\Danew_Backups\backup_2026-01-19.wim"

# Afficher résumé
Write-Host "Image créée: $($backup.ImagePath)"
Write-Host "Taille: $($backup.SizeGB) GB"
Write-Host "Métadonnées: $($backup.MetadataPath)"
```

#### Cas 2: Export avec Compression

```powershell
# Compression maximale (plus lent, meilleure compression)
$backup = Export-SystemImage `
  -SourceDrive "C:" `
  -OutputPath "X:\Backups\system_max_compressed.wim" `
  -CompressionLevel "Maximum" `
  -Description "System backup - Jan 2026 - Max compression"

# Compression rapide
$backup = Export-SystemImage `
  -SourceDrive "C:" `
  -OutputPath "X:\Backups\system_fast.wim" `
  -CompressionLevel "Fast" `
  -Description "System backup - Jan 2026 - Fast"
```

### Vérifier Intégrité Image

#### Cas 1: Vérification Basique

```powershell
Import-Module .\modules\Danew.Backup.psm1 -Force

# Vérifier présence et signature WIM
$verify = Verify-SystemImageIntegrity `
  -ImagePath "X:\Backups\backup_2026-01-19.wim"

# Afficher résumé
Write-Host "Image: $($verify.ImagePath)"
Write-Host "Taille: $([math]::Round($verify.SizeBytes / 1GB, 2)) GB"
Write-Host "Intégrité: $($verify.Integrity)"
Write-Host "Checksum: $($verify.Checksum)"
```

#### Cas 2: Vérification avec SHA256

```powershell
# Avec calcul SHA256 (plus lent sur gros fichiers)
$verify = Verify-SystemImageIntegrity `
  -ImagePath "X:\Backups\backup_2026-01-19.wim" `
  -ComputeChecksum

# Sauvegarder le checksum
$verify.Checksum | Out-File -FilePath "X:\Backups\backup_2026-01-19.wim.sha256"

# Vérifier ultérieurement
$storedChecksum = Get-Content "X:\Backups\backup_2026-01-19.wim.sha256"
if ($verify.Checksum -eq $storedChecksum) {
  Write-Host "✓ Checksum valide"
} else {
  Write-Host "✗ Checksum incorrect - fichier corrompu"
}
```

### Importer une Image

#### Cas 1: Restauration Simple

```powershell
Import-Module .\modules\Danew.Backup.psm1 -Force

# Restaurer image sur D:
$restore = Import-SystemImage `
  -ImagePath "X:\Backups\backup_2026-01-19.wim" `
  -TargetDrive "D:"

Write-Host "Restauration complétée: $($restore.Restored)"
```

#### Cas 2: Restauration avec Index

```powershell
# Si plusieurs images dans le WIM
$restore = Import-SystemImage `
  -ImagePath "X:\Backups\backup_with_multiple_images.wim" `
  -TargetDrive "D:" `
  -ImageIndex 2
```

### Gérer Sauvegardes

#### Cas 1: Lister Sauvegardes

```powershell
Import-Module .\modules\Danew.Backup.psm1 -Force

# Lister toutes les sauvegardes (tri par date)
$backups = Get-BackupList -BackupDir "X:\Danew_Backups"

# Afficher tableau
$backups | Format-Table -AutoSize

# Afficher détails
$backups | ForEach-Object {
  Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  Write-Host "Nom: $($_.Name)"
  Write-Host "Taille: $($_.SizeGB) GB"
  Write-Host "Créée: $($_.Created)"
  Write-Host "Description: $($_.Description)"
}
```

#### Cas 2: Lire Métadonnées

```powershell
# Récupérer métadonnées d'une sauvegarde
$metadata = Get-BackupInfo `
  -ImagePath "X:\Backups\backup_2026-01-19.wim"

if ($metadata) {
  Write-Host "Version: $($metadata.Version)"
  Write-Host "Source: $($metadata.SourceDrive)"
  Write-Host "Description: $($metadata.Description)"
  Write-Host "Compression: $($metadata.Compression)"
  Write-Host "Taille: $([math]::Round($metadata.SizeBytes / 1GB, 2)) GB"
}
```

---

## 3. SCÉNARIOS COMPLETS

### Scénario 1: Préparation Complète Avant Build

```powershell
# 1. Diagnostic complet
Write-Host "=== DIAGNOSTIC ===" -ForegroundColor Cyan
Import-Module .\modules\Danew.Diagnostic.psm1 -Force
$diag = Invoke-DanewDiagnostic -RootPath (Get-Location).Path

# 2. Vérifier les points critiques
$critical = $diag | Where-Object { $_.Test -in "Admin Rights", "PowerShell Version", "Windows ADK" }
$allPass = @($critical | Where-Object { -not $_.Passed }).Count -eq 0

if ($allPass) {
  Write-Host "✓ Tous les prérequis sont OK - Prêt pour build" -ForegroundColor Green
} else {
  Write-Host "✗ Prérequis manquants - Corriger avant build" -ForegroundColor Red
  exit 1
}

# 3. Lancer build
Write-Host "Lancement build..." -ForegroundColor Cyan
.\Build-All.ps1 -Bump patch -SyncUsb
```

### Scénario 2: Sauvegarde + Vérification

```powershell
# 1. Sauvegarder système
Write-Host "=== SAUVEGARDE SYSTÈME ===" -ForegroundColor Cyan
Import-Module .\modules\Danew.Backup.psm1 -Force

$timestamp = Get-Date -Format "yyyy-MM-dd_HHmmss"
$backup = Export-SystemImage `
  -SourceDrive "C:" `
  -OutputPath "X:\Backups\backup_$timestamp.wim" `
  -CompressionLevel "Maximum" `
  -Description "Sauvegarde système - $timestamp"

Write-Host "✓ Image créée: $($backup.ImagePath)" -ForegroundColor Green

# 2. Vérifier intégrité
Write-Host "=== VÉRIFICATION INTÉGRITÉ ===" -ForegroundColor Cyan
$verify = Verify-SystemImageIntegrity `
  -ImagePath $backup.ImagePath `
  -ComputeChecksum

Write-Host "Intégrité: $($verify.Integrity)" -ForegroundColor Green
Write-Host "Checksum: $($verify.Checksum)"

# 3. Sauvegarder le checksum
$verify.Checksum | Out-File -FilePath "$($backup.ImagePath).sha256"
Write-Host "✓ Checksum sauvegardé" -ForegroundColor Green
```

### Scénario 3: Restauration Complète

```powershell
# Trouver les sauvegardes disponibles
Import-Module .\modules\Danew.Backup.psm1 -Force
$backups = Get-BackupList -BackupDir "X:\Backups"

Write-Host "Sauvegardes disponibles:" -ForegroundColor Cyan
$backups | Select-Object -Property @{N='#';E={$_.'Name'}}, @{N='Taille';E={$_.SizeGB}}, @{N='Créée';E={$_.Created}} | Format-Table

# Sélectionner sauvegarde (ex: 0)
$selected = $backups[0]
Write-Host "Restauration de: $($selected.Name)" -ForegroundColor Yellow

# Vérifier checksum avant restauration
$imagePath = $selected.Path
$checksumPath = "$imagePath.sha256"

if (Test-Path $checksumPath) {
  $storedChecksum = Get-Content $checksumPath
  $verify = Verify-SystemImageIntegrity -ImagePath $imagePath
  
  if ($verify.Checksum -eq $storedChecksum) {
    Write-Host "✓ Checksum valide - Restauration sûre" -ForegroundColor Green
  } else {
    Write-Host "✗ Checksum incorrect - Restauration annulée" -ForegroundColor Red
    exit 1
  }
}

# Restaurer image
$restore = Import-SystemImage -ImagePath $imagePath -TargetDrive "D:"
Write-Host "✓ Restauration complétée" -ForegroundColor Green
```

---

## 4. BONNES PRATIQUES

### Sauvegardes

1. **Nommage cohérent**
   ```powershell
   # Format recommandé: backup_YYYYMMDD_description
   "backup_20260119_preupdate"
   "backup_20260119_preupdate.wim"
   ```

2. **Stockage**
   - Clé USB dédiée ≥ 32GB
   - Ou disque dur externe
   - Vérifier espace: `Get-DiskSpace`

3. **Vérification**
   - Toujours vérifier après export
   - Sauvegarder le SHA256
   - Tester restauration sur partition test

4. **Archivage**
   - Garder sauvegardes anciennes (3 dernières)
   - Datetaguer clairement
   - Documenter contenu

### Diagnostic

1. **Avant build**
   - Toujours lancer diagnostic
   - Corriger tous les [XX]
   - Les [!] sont avertissements

2. **Logs**
   - Consulter logs si erreur
   - Localisation: `C:\Temp\WinPE_OneClick_Logs\`

3. **Dépannage**
   - Si ADK absent: Télécharger Windows Assessment and Deployment Kit
   - Si USB absent: Préparer clé ≥7GB
   - Si espace disque: Nettoyer C: ou C:\Temp

---

## 5. TROUBLESHOOTING

### Export échoue

```powershell
# Vérifier que C: existe et contient Windows
Test-Path "C:\Windows\System32\config\SOFTWARE"

# Vérifier droits
[System.Security.Principal.WindowsPrincipal][System.Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([System.Security.Principal.WindowsBuiltInRole]::Administrator)

# Vérifier DISM
Get-Command dism.exe
```

### Import échoue

```powershell
# Vérifier image valide
Verify-SystemImageIntegrity -ImagePath "X:\backup.wim"

# Vérifier cible vide ou formatée
Get-ChildItem "D:\" | Measure-Object

# Vérifier espace cible
(Get-Item "D:\").Root.AvailableFreeSpace / 1GB
```

### Diagnostic échoue

```powershell
# Lancer avec verbose
Invoke-DanewDiagnostic -RootPath "." -Verbose

# Tester individuellement
Test-AdminRights -Verbose
Test-PowerShellVersion -Mode "CLI" -Verbose
Test-WindowsAdk -Verbose
```

---

Généré: 2026-01-19  
Module version: Danew.Diagnostic 1.0, Danew.Backup 1.0
