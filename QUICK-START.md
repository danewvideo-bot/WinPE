# 🚀 Quick Start - Danew USB Wizard

## ⚡ Demarrage Rapide (2 minutes)

### Etape 1: Diagnostic Prerequis
```
Double-clic sur: Diagnostic.cmd
↓
Attendre les resultats [OK] / [XX] / [!]
↓
Corriger les [XX] si necessaire
```

### Etape 2: Lancer le Build
```
Double-clic sur: Build-All.cmd
↓
Attendre le build complet
↓
Clé USB prête!
```

### Etape 3: Utiliser le Menu WinPE
```
Au boot de la clé USB:
↓
Menu automatique avec options:
  1) Réparer le boot UEFI
  2) Détecter Windows
  3) Appliquer une image
  4) Exporter rapport
  5) Sauvegarder système ★ NOUVEAU
  6) Restaurer système ★ NOUVEAU
  9) SelfTest
  0) Quitter
```

---

## 📁 Fichiers Essentiels

### 🎯 Points d'Entree
| Fichier | Utilisation | Prerequis |
|---------|-------------|-----------|
| `Diagnostic.cmd` | ✅ Verifier prerequis | Admin |
| `Build-All-Debug.cmd` | Diagnostic + Build | Admin |
| `Build-All.cmd` | Build final | Admin |
| `Build-All.ps1` | Build via ligne commande | Admin + PS |

### 📚 Documentation
| Fichier | Contenu |
|---------|---------|
| `README.md` | Documentation complète (700+ lignes) |
| `QUICK-START.md` | Demarrage rapide (ce fichier) |
| `EXAMPLES-USAGE.md` | 25+ exemples pratiques ★ NOUVEAU |
| `TROUBLESHOOT.md` | Guide dépannage détaillé |
| `FIXES-APPLIED.md` | Historique corrections |
| `SOLUTION-SUMMARY.txt` | Vue d'ensemble |

### ⚙️ Configuration
| Fichier | Role |
|---------|------|
| `config.psd1` | Configuration PowerShell (Arch, WorkDir, LogRoot) |
| `config.json` | Configuration payload WinPE |

### 🔧 Modules PowerShell
| Module | Lignes | Role |
|--------|--------|------|
| `Danew.WinPE.psm1` | 796 | Creation USB WinPE |
| `Danew.EFI.psm1` | 457 | Gestion EFI/BitLocker |
| `Danew.UI.psm1` | 570 | Interface WPF |
| `Danew.Disk.psm1` | 70 | Detection USB |
| `Danew.Common.psm1` | 186 | Utilitaires |

---

## 🔍 Problemes Courants

### ❌ "Fenetre s'ouvre et se ferme"
✅ **Solution:** Utiliser `Diagnostic.cmd` (now displays errors)

### ❌ "Pas d'administrateur"
✅ **Solution:** Clic-droit > Executer en tant qu'administrateur

### ❌ "copype.exe not found"
✅ **Solution:** Installer Windows ADK Deployment Tools
https://docs.microsoft.com/en-us/windows-hardware/get-started/adk-install

### ❌ "Espace disque insuffisant"
✅ **Solution:** 
- Editer `config.psd1`
- Changer `WorkDir` ou reduire `MinUsbSizeGB`

### ❌ "Clé USB non detectée"
✅ **Solution:** 
- Brancher clé ≥ 7GB
- Attendre 5 secondes
- Relancer diagnostic

---

## 📊 Flux Execution

```
┌─────────────────────────────────────────┐
│  Diagnostic.cmd ou Build-All-Debug.cmd  │
│  (Clic-droit > Admin)                   │
└─────────────────┬───────────────────────┘
                  ↓
        ┌─────────────────────┐
        │ Check Prerequisites │
        │ - Admin             │
        │ - PowerShell        │
        │ - ADK               │
        │ - Espace disque     │
        │ - Modules           │
        │ - USB devices       │
        └─────────────┬───────┘
                      ↓
              ┌───────────────┐
          [OK] │ [XX] Erreur?  │
              └───────────────┘
           /                  \
          ✓                    ✗ Corriger
          ↓                    ↓ (voir TROUBLESHOOT.md)
    ┌──────────────┐    Retry
    │  Build-All   │
    │  Start...    │
    │  Ou lancer   │
    │  direct      │
    └──────────────┘
```

---

## 🎯 Prochaines Etapes

### Si Diagnostic OK:
```
1. Double-clic: Build-All.cmd
2. Attendre completion
3. Clé USB prete a l'emploi
```

### Si Problemes:
```
1. Consulter TROUBLESHOOT.md
2. Corriger les problemes
3. Relancer Diagnostic.cmd
4. Retry
```

### Pour Options Avancees:
```
.\Build-All.ps1 -Bump minor          # Bump version
.\Build-All.ps1 -SyncUsb             # Sync USB
.\Build-All.ps1 -SyncUsbWhatIf       # Preview sync
```

---

## 📞 Support

### Documentation
- 📖 [README.md](README.md) - Vue d'ensemble complete
- 🔧 [TROUBLESHOOT.md](TROUBLESHOOT.md) - Dépannage detaille
- ✅ [FIXES-APPLIED.md](FIXES-APPLIED.md) - Corrections appliquees
- 🚀 [SOLUTION-SUMMARY.txt](SOLUTION-SUMMARY.txt) - Resume complet

### Logs
```
C:\temp\WinPE\DanewUsbWizard\logs\build-all_*.log
```

### Commandes Utiles
```powershell
# Voir version
Get-Content VERSION

# Voir config
Get-Content config.psd1

# Voir logs recents
Get-ChildItem logs\ -Newest 1 | Get-Content

# Lancer diagnostic
powershell -STA -ExecutionPolicy Bypass -File Build-All-Diagnostic.ps1
```

---

## ✅ Checklist Pret a Utiliser

- [x] Diagnostic.cmd fonctionne
- [x] Build-All-Debug.cmd fonctionne
- [x] Build-All.cmd fonctionne
- [x] README.md documente
- [x] TROUBLESHOOT.md documente
- [x] Erreurs d'encodage corrigees
- [x] Tests complets passes

---

**Vous etes pret a creer votre premiere USB Danew! 🎉**

**Date:** 2026-01-19
**Version:** 0.1.12
**Status:** OPERATIONNEL ✅
