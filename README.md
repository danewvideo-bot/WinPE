# 🖥️ Danew USB Wizard

**Version:** 0.1.12  
**Plateforme:** Windows 10/11  
**Langage:** PowerShell 5.1+ (5.1 pour UI, 7.0+ pour CLI)

## 📋 Table des Matières

- [Vue d'Ensemble](#vue-densemble)
- [Prérequis](#prérequis)
- [Installation](#installation)
- [Utilisation](#utilisation)
- [Architecture](#architecture)
- [Modules](#modules)
- [Build & Développement](#build--développement)
- [Configuration](#configuration)
- [Dépannage](#dépannage)
- [Contribution](#contribution)

---

## 🎯 Vue d'Ensemble

**Danew USB Wizard** est une application PowerShell complète pour créer des clés USB WinPE bootables (UEFI) destinées à la sauvegarde et réparation de systèmes Windows.

### ✨ Fonctionnalités Principales

✅ **Création USB WinPE automatisée**
- Partitionnement UEFI (FAT32 + NTFS)
- Injection kernel WinPE + payload personnalisé
- Boot automatique vers menu Danew

✅ **Outils de Maintenance Intégrés**
- Menu de sélection des outils (`DanewMenu.ps1`)
- Tests d'auto-vérification (`SelfTest.ps1`)
- Réparation système (`RunFix.cmd`)

✅ **Gestion Avancée**
- Détection et déverrouillage BitLocker
- Réparation ESP insuffisante
- Sélection disque sécurisée (blocage disques système)

✅ **Interface Professionnelle**
- UI WPF intuitive avec sélection disque
- Barre de progression en temps réel
- Affichage logs en direct
- Gestion d'erreurs avec dialogs Windows

✅ **Build & Deployment**
- Versioning sémantique
- Build portable
- Synchronisation vers USB
- Logs détaillés

---

## 🔧 Prérequis

### Système d'Exploitation
- Windows 10/11 (version 1909+)
- Droits **Administrateur** obligatoires

### PowerShell
- **PowerShell 5.1** (Desktop) - Interface WPF
- **PowerShell 7.0+** (Core optionnel) - CLI, variante cross-platform

### Assemblies .NET
- `PresentationFramework` (WPF)
- `PresentationCore`
- `WindowsBase`

### ADK Windows (Windows Assessment and Deployment Kit)
Pour la création WinPE, installer :
- **Deployment Tools** (copype.exe, MakeWinPEMedia.exe)
- **Windows PE add-on** (Optional)

Télécharger depuis : https://docs.microsoft.com/en-us/windows-hardware/get-started/adk-install

### Matériel
- Clé USB ≥ 7GB (configurable dans `config.psd1`)
- Clé **non système** et **non boot**

### Espace Disque
- ~3-5GB pour WorkDir temporaire (WinPE build)
- Configurable dans `config.psd1`

---

## 📦 Installation

### 1. Cloner/Télécharger le Projet
```powershell
git clone https://github.com/YourOrg/DanewUsbWizard.git
cd DanewUsbWizard
```

### 2. Vérifier les Prérequis
```powershell
# Vérifier PowerShell
$PSVersionTable.PSVersion

# Vérifier ADK
Get-Command copype.exe -ErrorAction SilentlyContinue
```

### 3. Installer ADK (si absent)
Télécharger depuis Microsoft et installer **Deployment Tools**

### 4. Configuration Optionnelle
Éditer `config.psd1` si besoin :
```powershell
@{
    Arch         = 'amd64'                    # Architecture (amd64 ou x86)
    WorkDir      = 'C:\Temp\DanewWinPE'     # Répertoire de travail
    MinUsbSizeGB = 7                         # Taille USB min
    LogRoot      = 'C:\Temp\WinPE_OneClick_Logs'  # Logs
    AppTitle     = 'Danew USB Wizard - Create WinPE USB (SAV)'
}
```

---

## 🚀 Utilisation

### Lancement Simple (Recommandé)

**Option 1 : Double-clic (lanceur)**
```
Double-clic sur : RunDanewUsbWizard.cmd
```
→ PowerShell s'élève automatiquement en administrateur et lance l'UI WPF

**Option 2 : Ligne de commande (Admin)**
```powershell
# PowerShell 5.1 avec UI
.\launcher.ps1

# PowerShell 7.0+ avec STA
pwsh -STA -File .\New-DanewUsbWizard.ps1
```

### Flux d'Utilisation Typique

1. **Lancement** → Vérification Admin automatique
2. **Sélection Disque** → Liste des USB éligibles
3. **Confirmation** → Barre de progression
4. **Création** → Partitionnement, copy données, patch boot
5. **Finition** → Vérification hash, clé USB prête

### Options Avancées

#### CLI avec paramètres
```powershell
.\Start-DanewUsbWizard.ps1 `
  -DiskNumber 1 `
  -PayloadRoot "payload" `
  -WorkDir "C:\Temp\MyWorkDir" `
  -LogPath "C:\Logs\danew.log" `
  -ValidateBootWimHash
```

#### Paramètres CLI
- `-DiskNumber <int>` : Numéro disque (au lieu de sélection UI)
- `-PayloadRoot <path>` : Chemin payload personnalisé
- `-WorkDir <path>` : Répertoire de travail WinPE
- `-LogPath <path>` : Fichier log personnalisé
- `-Cli` : Mode console (sans UI)
- `-ValidateBootWimHash` : Vérification hash boot.wim

---

## 🏗️ Architecture

### Vue d'Ensemble

```
┌─────────────────────────────────────────────────────────────┐
│                   DANEW USB WIZARD                          │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  📱 UI Layer (WPF)                                         │
│     └─ DanewWizard.xaml / Danew.UI.psm1                  │
│                                                             │
│  🔧 Core Modules                                           │
│     ├─ Danew.WinPE.psm1     (Création WinPE)            │
│     ├─ Danew.EFI.psm1       (Gestion EFI/BitLocker)     │
│     ├─ Danew.Disk.psm1      (Détection USB)             │
│     ├─ Danew.Common.psm1    (Utilitaires)               │
│     └─ Danew.*.psm1         (Autres modules)             │
│                                                             │
│  🚀 Entry Points                                           │
│     ├─ launcher.ps1                 (PS5.1 + UI)         │
│     ├─ Start-DanewUsbWizard.ps1    (PS5.1 orchestration)│
│     └─ New-DanewUsbWizard.ps1      (PS7.0+ variante)   │
│                                                             │
│  📦 Payload (Runtime WinPE)                               │
│     ├─ DanewMenu.ps1               (Menu principal)      │
│     ├─ SelfTest.ps1                (Tests système)       │
│     ├─ RunFix.cmd                  (Réparation)          │
│     └─ modules/                    (Modules WinPE)       │
│                                                             │
│  🛠️ Build System                                           │
│     ├─ Build-All.ps1               (Build complet)       │
│     ├─ Build-Portable.ps1          (Portable)            │
│     └─ Sync-Payload.ps1            (Synchro)             │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

### Flux d'Exécution

```
1. Launcher (launcher.ps1 / RunDanewUsbWizard.cmd)
   ├─ Vérification Admin
   ├─ Création répertoire logs
   └─ Élévation PowerShell

2. Orchestration (Start-DanewUsbWizard.ps1)
   ├─ Chargement config
   ├─ Import modules
   └─ Lancement UI WPF

3. UI (Danew.UI.psm1 / DanewWizard.xaml)
   ├─ Détection disques USB (Danew.Disk.psm1)
   ├─ Présentation liste
   └─ Sélection utilisateur

4. Création WinPE (Danew.WinPE.psm1)
   ├─ Build WinPE workspace (copype.exe)
   ├─ Génération média (MakeWinPEMedia.exe)
   ├─ Formatage USB (FAT32 + NTFS)
   ├─ Copy données WINPE + DANEW
   ├─ Patch startnet.cmd
   └─ Vérification hash (optionnel)

5. Gestion Spéciale (Danew.EFI.psm1)
   ├─ Détection BitLocker
   ├─ Déverrouillage automatique
   └─ Réparation ESP si nécessaire

6. Logs & Rapports
   └─ Stockage : C:\Temp\WinPE_OneClick_Logs\
```

---

## 📚 Modules

### Danew.WinPE.psm1 (796 lignes)
**Responsabilité:** Création USB WinPE complète

**Fonctions principales:**
- `New-DanewWinPEUsb` : Créer USB WinPE
- `_Run-Process` : Exécution processus avec log
- `Test-DanewBootWimStartnet` : Vérification boot.wim

**Flux:**
1. Build WinPE workspace via `copype.exe`
2. Génération ISO WinPE via `MakeWinPEMedia.exe`
3. Montage ISO, extraction fichiers
4. Partitionnement USB (GPT UEFI)
5. Copy données
6. Patch `startnet.cmd` → injection DanewMenu
7. Vérification hash boot.wim

### Danew.EFI.psm1 (457 lignes)
**Responsabilité:** Gestion EFI, BitLocker, réparation système offline

**Fonctions principales:**
- `Get-DanewBitLockerStatus` : État BitLocker
- `Unlock-DanewBitLockerVolume` : Déverrouillage
- `Repair-DanewEsp` : Réparation/création ESP
- `Test-IsGPTDisk` : Vérification GPT

**Capacités:**
- Détection Windows offline (sonde robuste)
- Gestion BitLocker (Get-BitLockerVolume, Unlock-BitLocker)
- ESP insuffisante → création NEW ESP + bcdboot

### Danew.UI.psm1 (570 lignes)
**Responsabilité:** Interface WPF professionnelle

**Composants:**
- Sélection disque USB
- Barre de progression
- Affichage logs en temps réel
- Gestion dialogs/erreurs
- Évite popups console

**Événements WPF gérés:**
- Loaded
- Button.Click
- Window.Closed

### Danew.Disk.psm1 (70 lignes)
**Responsabilité:** Détection disques USB

**Fonctions:**
- `Get-EligibleUsbDisks` : Liste USB ≥ MinSize, non système, non boot
- `Disk-ContainsWindows` : Vérification Windows présent

**Filtres appliqués:**
```powershell
BusType -eq "USB" -and
Size -ge $minBytes -and
-not IsSystem -and
-not IsBoot
```

### Danew.Common.psm1 (186 lignes)
**Responsabilité:** Utilitaires partagés

**Fonctions:**
- `Ensure-Admin` : Escalade privilèges
- `Initialize-Log` : Init fichier log
- `Write-Log` : Écriture log
- `Get-DriveLetterByLabel` : Lettre lecteur par label

### Danew.Backup.psm1 (380 lignes)
**Responsabilité:** Gestion sauvegarde et restauration d'images système

**Fonctions principales:**
- `Export-SystemImage` : Créer image WIM compressée d'une installation Windows
  - Paramètres: SourceDrive, OutputPath, CompressionLevel (Fast/Maximum)
  - Utilise: `dism.exe /Capture-Image` avec vérification
  - Crée: Fichier .wim + métadonnées JSON (.backup.json)
  - Retour: PSCustomObject avec ImagePath, MetadataPath, SizeGB, Created

- `Import-SystemImage` : Restaurer image WIM sur un lecteur cible
  - Paramètres: ImagePath, TargetDrive, ImageIndex
  - Utilise: `dism.exe /Apply-Image` avec vérification
  - Retour: PSCustomObject avec TargetDrive, ImageFile, Restored

- `Verify-SystemImageIntegrity` : Vérifier intégrité image WIM
  - Contrôles: Signature WIM header (MSWIM\0\0\0), calcul SHA256 optionnel
  - Retour: PSCustomObject avec Integrity, Checksum, etc.

- `Get-BackupInfo` : Récupère métadonnées sauvegarde
  - Lit fichier .backup.json associé
  - Retour: Objet métadonnées ou NULL

- `Get-BackupList` : Liste sauvegardes d'un répertoire
  - Tri: Par date décroissante (plus récent d'abord)
  - Retour: Tableau PSCustomObject

**Usage exemple:**
```powershell
Import-Module modules\Danew.Backup.psm1 -Force

# Exporter image système
$backup = Export-SystemImage -SourceDrive "C:" `
  -OutputPath "D:\Backups\backup.wim" `
  -CompressionLevel Maximum

# Vérifier intégrité
$verify = Verify-SystemImageIntegrity -ImagePath "D:\Backups\backup.wim" `
  -ComputeChecksum

# Restaurer image
Import-SystemImage -ImagePath "D:\Backups\backup.wim" -TargetDrive "D:"

# Lister sauvegardes
Get-BackupList -BackupDir "D:\Backups"
```

### Danew.Diagnostic.psm1 (400 lignes)
**Responsabilité:** Diagnostic automatisé et vérification des prérequis

**Fonctions de test:**
- `Test-AdminRights` : Vérifie droits administrateur
- `Test-PowerShellVersion` : Valide version PS (5.1+ pour UI, 7.0+ pour CLI)
- `Test-StaMode` : Vérifie mode STA (Single-Threaded Apartment) pour WPF
- `Test-KeyFiles` : Vérifie présence fichiers essentiels
  - Cibles: Build-All.ps1, Start-DanewUsbWizard.ps1, config.json, config.psd1
- `Test-DanewModules` : Valide présence et syntaxe tous modules
  - Détecte modules vides, manquants ou avec erreurs syntax
- `Test-WindowsAdk` : Cherche Windows ADK (copype.exe, MakeWinPEMedia.exe)
  - Supporte Win10/11 Kit, 32-bit et 64-bit
- `Test-DiskSpace` : Vérifie espace disque disponible (5GB par défaut)
  - Configurable par paramètre
- `Test-ConfigFiles` : Valide JSON (config.json) et POSH (config.psd1)
- `Test-UsbAvailability` : Détecte clé USB compatible (≥7GB)
  - Filtre: BusType=USB, non-système, non-boot

**Fonction principale:**
- `Invoke-DanewDiagnostic` : Lance diagnostic complet
  - Paramètres: RootPath (obligatoire), Mode ("UI" ou "CLI"), MinDiskSpaceGB, MinUsbSizeGB
  - Retour: Array PSCustomObject avec Test, Passed, Detail
  - Affichage: Console colorée avec symboles ✓/✗/!

**Usage exemple:**
```powershell
Import-Module modules\Danew.Diagnostic.psm1 -Force

# Diagnostic complet
$results = Invoke-DanewDiagnostic -RootPath "C:\DanewUsbWizard"

# Voir seulement les tests échoués
$results | Where-Object { -not $_.Passed } | Format-Table

# Diagnostic en mode UI avec vérifications strictes
Invoke-DanewDiagnostic -RootPath "C:\DanewUsbWizard" -Mode "UI" `
  -MinDiskSpaceGB 5 -MinUsbSizeGB 7
```

### Danew.SystemRepair.psm1
**Responsabilité:** Outils réparation système
*Détails à compléter*

### Danew.Payload.psm1
**Responsabilité:** Gestion payload WinPE
*Détails à compléter*

---

## 🔨 Build & Développement

### Build Complet
```powershell
# Mode standard (patch version)
.\Build-All.ps1

# Avec bump mineur
.\Build-All.ps1 -Bump minor

# Avec bump majeur
.\Build-All.ps1 -Bump major

# Avec timestamp
.\Build-All.ps1 -Stamp

# Sans EXE (PowerShell seulement)
.\Build-All.ps1 -NoExe

# Avec synchronisation USB
.\Build-All.ps1 -SyncUsb -UsbLabel "DANEW"
```

### Paramètres Build

| Paramètre | Type | Défaut | Description |
|-----------|------|--------|-------------|
| `-Bump` | string | patch | Version : none, patch, minor, major |
| `-Stamp` | switch | false | Ajouter timestamp à la version |
| `-NoExe` | switch | false | Ignorer conversion PS→EXE |
| `-NoWinPE` | switch | false | Ignorer build WinPE |
| `-NoPortable` | switch | false | Ignorer mode portable |
| `-SyncUsb` | switch | false | Synchroniser clé USB |
| `-SyncUsbWhatIf` | switch | false | Simulation sync USB |
| `-UsbLabel` | string | DANEW | Label USB cible |
| `-UsbDestSubDir` | string | Danew | Sous-dossier destination |
| `-UsbMirror` | switch | false | Mode miroir |
| `-LogPath` | string | — | Chemin log personnalisé |

### Build Portable
```powershell
.\Build-Portable.ps1 -Bump patch
```

### Versioning

**Fichier VERSION:**
```
0.1.12
```

**Format:** `MAJOR.MINOR.PATCH`

**Bump automatique:**
```powershell
Get-Version.ps1
```

**Auto-incrémentation:**
- `patch` → 0.1.12 → 0.1.13
- `minor` → 0.1.13 → 0.2.0
- `major` → 0.2.0 → 1.0.0

### Scripts de Build

| Script | Rôle |
|--------|------|
| `Build-All.ps1` | Build complet (EXE, WinPE, portable, sync) |
| `Build-All.cmd` | Wrapper Build-All (clic-droit Admin) |
| `Build-Portable.ps1` | Build portable uniquement |
| `Build-Portable.cmd` | Wrapper Portable |
| `Get-Version.ps1` | Gestion versioning |
| `Init-DanewConfig.ps1` | Initialisation config |
| `Sync-Payload.ps1` | Synchro payload |

### Variables d'Environnement
```powershell
$WorkDir       # C:\Temp\DanewWinPE
$LogRoot       # C:\Temp\WinPE_OneClick_Logs
$PayloadRoot   # payload/ (relatif)
$Arch          # amd64
```

---

## ⚙️ Configuration

### config.psd1 (Configuration PowerShell)

```powershell
@{
    Arch         = 'amd64'                              # Architecture (amd64 / x86)
    WorkDir      = 'C:\Temp\DanewWinPE'                # Espace de travail WinPE
    MinUsbSizeGB = 7                                    # Taille USB minimale (GB)
    LogRoot      = 'C:\Temp\WinPE_OneClick_Logs'       # Répertoire logs
    AppTitle     = 'Danew USB Wizard - Create WinPE USB (SAV)'  # Titre UI
    PayloadRoot  = 'payload'                            # Chemin payload
}
```

### config.json (Payload WinPE)

```json
{
  "logging": {
    "forcePath": "X:\\Danew\\Logs"
  },
  "image": {
    "defaultIndex": 1
  },
  "selfTest": {
    "enabled": true,
    "onBoot": true,
    "failMode": "warn"
  }
}
```

**Paramètres:**
- `logging.forcePath` : Chemin logs obligatoire (X: = drive WinPE)
- `image.defaultIndex` : Index image WinPE par défaut (1-based)
- `selfTest.enabled` : Tests auto activés
- `selfTest.onBoot` : Tests au boot WinPE
- `selfTest.failMode` : Mode défaut : "warn" ou "error"

### Branding

**assets/branding.psd1:**
```powershell
# Personnalisation UI (logos, couleurs, etc.)
```

---

## 🐛 Dépannage

### Erreur : "Admin requis"

**Cause:** PowerShell n'est pas lancé en administrateur

**Solution:**
```powershell
# Option 1 : Clic-droit > Exécuter en tant qu'admin
# Option 2 : Via launcher (auto-escalade)
.\launcher.ps1

# Option 3 : Via cmd
RunDanewUsbWizard.cmd
```

### Erreur : "STA requis"

**Cause:** WPF nécessite Single-Threaded Apartment

**Solution:**
```powershell
# PowerShell 5.1 (automatique via launcher)
powershell -STA -File .\Start-DanewUsbWizard.ps1

# PowerShell 7.0+
pwsh -STA -File .\New-DanewUsbWizard.ps1
```

### Erreur : "copype.exe not found"

**Cause:** ADK Windows non installée

**Solution:**
1. Télécharger Windows ADK : https://docs.microsoft.com/en-us/windows-hardware/get-started/adk-install
2. Installer **Deployment Tools**
3. Ajouter `C:\Program Files (x86)\Windows Kits\10\Assessment and Deployment Kit\Deployment Tools\amd64\` au PATH
4. Ou redémarrer PowerShell pour recharger PATH

### Erreur : "No eligible USB disk found"

**Cause:** Aucune clé USB détectée correspondant aux critères

**Critères:**
- Bus type = USB
- Taille ≥ 7GB (configurable)
- Pas disque système
- Pas disque boot

**Solution:**
1. Brancher clé USB (≥7GB)
2. Attendre 5 secondes
3. Vérifier dans `Disque Gestion` : clé USB visible, non système, non boot
4. Si clé = disque système → impossible, utiliser autre clé
5. Si petite clé : éditer `config.psd1`, réduire `MinUsbSizeGB`

### Erreur : "PresentationFramework not available"

**Cause:** WPF n'est pas disponible (PowerShell Core sur non-Windows?)

**Solution:**
- Utiliser **PowerShell 5.1** (Desktop Windows uniquement)
- Ou mode CLI sans UI avec paramètre `-Cli`

### Erreur : "BitLocker locked"

**Cause:** Disque destination chiffré avec BitLocker

**Solution:** (Automatique via `Danew.EFI.psm1`)
- Détection automatique BitLocker
- Déverrouillage automatique
- Si problème : déverrouiller manuellement : `Unlock-BitLocker -MountPoint "E:" -EncryptionMethod Aes256`

### Erreur : "Insufficient free space on disk"

**Cause:** WorkDir sur partition saturée

**Solution:**
```powershell
# Éditer config.psd1
WorkDir = 'D:\DanewWinPE'  # Changer partition

# Ou libérer espace
Remove-Item 'C:\Temp\DanewWinPE' -Recurse -Force
```

### Logs Détaillés

**Emplacement logs:**
```
C:\Temp\WinPE_OneClick_Logs\
```

**Format log:**
```
[2026-01-19 14:30:45] [INFO] Initializing...
[2026-01-19 14:30:46] [PROGRESS] 10% Building WinPE
[2026-01-19 14:30:50] [ERROR] copype.exe failed
[2026-01-19 14:31:00] [SUCCESS] USB Ready
```

**Consultation logs:**
```powershell
Get-Content "C:\Temp\WinPE_OneClick_Logs\*" -Tail 50
```

---

## 📁 Structure Fichiers

```
DanewUsbWizard/
│
├── 📄 README.md                          ← Vous êtes ici
├── 📄 VERSION                            (Version: 0.1.12)
├── 📄 version.txt
│
├── 🚀 Entry Points
│   ├── launcher.ps1                      (Point d'entrée principal, PS5.1+UI)
│   ├── Start-DanewUsbWizard.ps1         (Orchestration PS5.1)
│   ├── New-DanewUsbWizard.ps1           (Variante PS7.0+)
│   ├── RunDanewUsbWizard.cmd            (Lanceur double-clic)
│   ├── RunFix.cmd                       (Réparation système)
│   └── SelfTest.old.ps1                 (Ancien test auto)
│
├── 🔨 Build System
│   ├── Build-All.ps1                    (Build complet)
│   ├── Build-All.cmd                    (Wrapper Build-All)
│   ├── Build-Portable.ps1               (Build portable)
│   ├── Build-Portable.cmd               (Wrapper portable)
│   ├── Get-Version.ps1                  (Gestion versioning)
│   ├── Init-DanewConfig.ps1             (Init config)
│   └── Sync-Payload.ps1                 (Synchro payload)
│
├── ⚙️ Configuration
│   ├── config.psd1                      (Config PowerShell)
│   └── config.json                      (Config globale)
│
├── 📚 Modules PowerShell (modules/)
│   ├── Danew.UI.psm1                    (Interface WPF - 570 lignes)
│   ├── Danew.WinPE.psm1                 (Création WinPE - 796 lignes)
│   ├── Danew.EFI.psm1                   (EFI/BitLocker - 457 lignes)
│   ├── Danew.Disk.psm1                  (Détection USB - 70 lignes)
│   ├── Danew.Common.psm1                (Utilitaires - 186 lignes)
│   ├── Danew.Backup.psm1                (Sauvegarde)
│   ├── Danew.Diagnostic.psm1            (Diagnostics)
│   ├── Danew.SystemRepair.psm1          (Réparation système)
│   ├── Danew.Payload.psm1               (Gestion payload)
│   ├── Danew.Common.psm1old             (Backup ancien)
│   ├── Danew.EFI.psm1old                (Backup ancien)
│   └── EfiResize.OLD                    (Ancien outil)
│
├── 📦 Payload WinPE (payload/)
│   ├── DanewMenu.ps1                    (Menu principal WinPE)
│   ├── SelfTest.ps1                     (Tests système)
│   ├── RunFix.cmd                       (Réparation)
│   ├── config.json                      (Config WinPE)
│   ├── VERSION                          (Version WinPE)
│   ├── modules/
│   │   ├── Danew.Common.psm1           (Utilitaires WinPE)
│   │   ├── Danew.EFI.psm1              (EFI WinPE)
│   │   └── Danew.SystemRepair.psm1     (Réparation WinPE)
│   └── winpe/
│       └── startnet.cmd                 (Script boot WinPE)
│
├── 🎨 Interface Utilisateur (ui/)
│   └── DanewWizard.xaml                 (Interface WPF)
│
├── 🏷️ Branding (assets/)
│   └── branding.psd1                    (Personnalisation UI)
│
├── 💻 PowerShell Core (pwsh/)
│   ├── pwsh.exe / pwsh.dll              (PowerShell Core exécutable)
│   ├── pwsh.config.json
│   ├── pwsh.deps.json
│   ├── pwsh.runtimeconfig.json
│   ├── Modules/                         (Modules intégrés)
│   ├── en-US/                           (Ressources locales)
│   ├── ...
│   └── ThirdPartyNotices.txt
│
├── 🛠️ Outils (tools/)
│   ├── ps2exe/                          (Convertisseur PS→EXE)
│   └── pwsh/                            (PowerShell Core optionnel)
│
├── 📊 Logs (logs/)
│   └── (Créé dynamiquement au runtime)
│
├── 📦 Dépendances (deps/)
│   └── (Dépendances externes)
│
├── 💾 USB Mount (USB/)
│   └── (Point de montage USB pendant création)
│
└── 📑 Fichiers Diversifiés
    ├── DanewMenu.ps1
    └── (Autres scripts root)
```

---

## 🔌 Dépendances Externes

### Requis

| Composant | Version | Source | Installation |
|-----------|---------|--------|--------------|
| **Windows ADK** | 10+ | Microsoft | [Télécharger](https://docs.microsoft.com/en-us/windows-hardware/get-started/adk-install) |
| **copype.exe** | — | ADK (Deployment Tools) | Inclus ADK |
| **MakeWinPEMedia.exe** | — | ADK (Deployment Tools) | Inclus ADK |
| **bcdboot.exe** | — | ADK (Deployment Tools) | Inclus ADK |

### Optionnel

| Composant | Version | Rôle |
|-----------|---------|------|
| **PowerShell 7.0+** | 7.0+ | Variante PS7 CLI |
| **ps2exe** | 2.9+ | Conversion PS→EXE (inclus) |
| **Windows PE** | 10+ | Image WinPE de base (fournie par ADK) |

### Modules PowerShell

Tous les modules sont **internes** au projet (pas de dépendances externes PSGallery).

Modules utilisés:
- `PresentationFramework` (.NET natif - WPF)
- `PresentationCore` (.NET natif)
- `WindowsBase` (.NET natif)
- `Hyper-V` (optionnel, pour gestion disques avancée)
- `Storage` (Disks, Volumes, Partitions)
- `BitLocker` (Gestion BitLocker)

---

## 📝 Contribution

### Code Style

**PowerShell:**
```powershell
# ✅ Bon
function Invoke-MyFunction {
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )
    
    Set-StrictMode -Version Latest
    $ErrorActionPreference = "Stop"
}

# ❌ Mauvais
function Invoke-MyFunction($Path) {
    ...
}
```

**Conventions:**
- `Set-StrictMode -Version Latest` au début des modules
- `$ErrorActionPreference = "Stop"` pour erreurs critiques
- Nommage PascalCase pour fonctions/variables publiques
- Nommage _camelCase pour fonctions privées
- Commentaires : `# Comment` pour lignage, `<# Bloc #>` pour fonctions
- Logs structurés : `[timestamp] [LEVEL] Message`

### Pull Requests

1. Fork le projet
2. Créer branche feature : `git checkout -b feat/my-feature`
3. Commit changesets logiques : `git commit -m "feat: add feature"`
4. Push : `git push origin feat/my-feature`
5. PR vers `main` avec description

### Bugs Signalés

1. Vérifier issues existantes
2. Créer issue avec :
   - Description claire
   - Étapes reproduction
   - Logs (`C:\Temp\WinPE_OneClick_Logs\`)
   - Environnement (OS, PS version, ADK version)

### Roadmap

- [ ] Support PowerShell Remoting
- [ ] Gestion multi-disques parallèle
- [ ] Dashboard web optionnel
- [ ] Intégration SCCM/MECM
- [ ] Signature EFI Secure Boot

---

## 📄 Licence

À définir (Voir `LICENSE.txt` si présent)

---

## 👥 Support & Contact

**Documentation:** Ce fichier (README.md)  
**Logs:** `C:\Temp\WinPE_OneClick_Logs\`  
**Issues:** [GitHub Issues](#)  

---

## 📚 Références

- [Windows PE Documentation](https://docs.microsoft.com/en-us/windows-hardware/manufacture/desktop/winpe-intro)
- [ADK Installation](https://docs.microsoft.com/en-us/windows-hardware/get-started/adk-install)
- [PowerShell Documentation](https://docs.microsoft.com/en-us/powershell/)
- [WPF Tutorial](https://docs.microsoft.com/en-us/dotnet/desktop/wpf/)
- [BitLocker Management](https://docs.microsoft.com/en-us/windows/security/information-protection/bitlocker/)

---

**Last Updated:** 2026-01-19  
**Version:** 0.1.12

