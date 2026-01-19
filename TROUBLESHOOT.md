# 🔧 Dépannage : Build-All.cmd s'ouvre et se ferme

## 🚨 Problème

Quand vous lancez **Build-All.cmd**, la fenêtre s'ouvre et se ferme **immédiatement** sans montrer les erreurs.

## ✅ Solutions

### Solution 1: Utiliser le script diagnostic (RECOMMANDÉ)

**La plus facile !** Ce script vérifie tous les prérequis et vous dit exactement ce qui ne va pas.

```
1. Clic-droit sur Build-All-Debug.cmd
2. Choisir "Exécuter en tant qu'administrateur"
3. La fenêtre restera ouverte et vous affichera les erreurs
```

**OU en PowerShell:**
```powershell
powershell -STA -ExecutionPolicy Bypass -File Build-All-Diagnostic.ps1
```

---

### Solution 2: Voir les erreurs manuellement

Modifiez le raccourci ou ouvrez une fenêtre cmd puis:

```cmd
cd /d "C:\temp\WinPE\DanewUsbWizard"
Build-All.cmd
```

Maintenant la fenêtre restera ouverte avec **pause** et vous verrez les erreurs.

---

### Solution 3: Utiliser PowerShell directement

```powershell
# Option A : PowerShell 5.1 (Desktop)
powershell -STA -ExecutionPolicy Bypass -File "C:\temp\WinPE\DanewUsbWizard\Start-DanewUsbWizard.ps1"

# Option B : PowerShell 7.0+ (Core)
pwsh -STA -ExecutionPolicy Bypass -File "C:\temp\WinPE\DanewUsbWizard\New-DanewUsbWizard.ps1"
```

---

## 🔍 Causes Possibles

| Cause | Solution |
|-------|----------|
| **Pas d'admin** | Clic-droit > Exécuter en tant qu'admin |
| **ADK Windows manquant** | Télécharger Windows ADK (Deployment Tools) |
| **PowerShell pas en STA** | Lancer avec `-STA` flag |
| **Fichier config.psd1 invalide** | Vérifier syntaxe PowerShell |
| **copype.exe non trouvé** | Installer ADK ou ajouter au PATH |
| **Espace disque insuffisant** | Libérer espace ou éditer `config.psd1` (réduire WorkDir) |
| **Erreur path** | Assurez-vous de la version Windows (ADK 10+) |

---

## 📋 Checklist Diagnostic

✅ **Droits Admin?**
```powershell
[bool]([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
```
Retour attendu: `True`

✅ **PowerShell version?**
```powershell
$PSVersionTable.PSVersion
```
Retour attendu: `5.1` ou plus

✅ **ADK installé?**
```powershell
where copype.exe
```
Retour attendu: Chemin vers copype.exe

✅ **Espace disque?**
```powershell
(Get-PSDrive -Name "C").Free / 1GB
```
Retour attendu: `> 5` GB

✅ **Modules présents?**
```powershell
Test-Path "C:\temp\WinPE\DanewUsbWizard\modules\Danew.WinPE.psm1"
```
Retour attendu: `True`

---

## 🛠️ Installation ADK Windows (si manquant)

**1. Télécharger ADK:**
https://docs.microsoft.com/en-us/windows-hardware/get-started/adk-install

**2. Installer:**
- Ouvrir l'installateur
- Choisir **Deployment Tools**
- Cocher les options pour UEFI, WinPE
- Installer dans `C:\Program Files (x86)\Windows Kits\10\`

**3. Vérifier:**
```powershell
where copype.exe
```

**4. Si absent du PATH:**
```powershell
$env:Path += ';C:\Program Files (x86)\Windows Kits\10\Assessment and Deployment Kit\Deployment Tools\amd64\'
```

---

## 📝 Logs Détaillés

Après avoir lancé le diagnostic, les logs se trouvent ici:

```
C:\temp\WinPE\DanewUsbWizard\logs\build-all_*.log
```

**Consulter les logs:**
```powershell
Get-ChildItem "C:\temp\WinPE\DanewUsbWizard\logs\*" -Newest 1 | Get-Content
```

---

## 🎯 Prochaines Étapes

Une fois le diagnostic réussi:

```cmd
REM Solution A : Double-clic sur
Build-All-Debug.cmd

REM Solution B : Ligne de commande
powershell -STA -ExecutionPolicy Bypass -File Build-All-Diagnostic.ps1
```

---

## ❓ Autres Questions?

- **README.md** : Documentation complète du projet
- **Build-All.ps1** : Source du build, analyse pour détails
- **logs/** : Traces détaillées après chaque build

---

**Dernier update:** 2026-01-19
