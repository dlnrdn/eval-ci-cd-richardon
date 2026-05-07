# Commandes à lancer pour finaliser le rendu

## 1. Créer le repo privé GitHub

Nom conseillé :

```txt
eval-ci-cd-dylan-richardon
```

Commandes :

```bash
git init
git branch -M main
git add .
git commit -m "Rendu CI CD QuickNotes"
git remote add origin https://github.com/TON-COMPTE/eval-ci-cd-dylan-richardon.git
git push -u origin main
```

## 2. Lancer Jenkins

### Windows PowerShell

```powershell
.\scripts\start-jenkins.ps1
```

### Linux/macOS

```bash
./scripts/start-jenkins.sh
```

## 3. Jenkins — plugins à installer

- Git
- Pipeline
- Pipeline: Stage View
- Docker Pipeline
- Credentials Binding
- Workspace Cleanup
- Blue Ocean

## 4. Jenkins — credentials à créer

| ID | Type | Valeur |
|---|---|---|
| `github-token` | Secret text ou username/password | Token GitHub |
| `discord-webhook` | Secret text | Webhook Discord du sujet |
| `render-deploy-hook` | Secret text | Deploy Hook Render |

## 5. Créer le job Jenkins

```txt
New Item
→ Pipeline
→ quicknotes-ci-cd
→ Pipeline script from SCM
→ Git
→ Repository URL : repo GitHub privé
→ Credentials : github-token
→ Branch : main
→ Script Path : Jenkinsfile
```

## 6. Render

Créer un Web Service :

```txt
Language : Docker
Health Check Path : /health
```

Récupérer le Deploy Hook et l'ajouter dans Jenkins sous `render-deploy-hook`.

## 7. Premier build pour capturer les erreurs

Lancer le build avec :

```txt
SECURITY_STRICT_MODE=true
```

Faire les captures des stages rouges ou instables.

## 8. Build final pour aller jusqu'au déploiement

Relancer avec :

```txt
SECURITY_STRICT_MODE=false
RENDER_APP_URL=https://TON-SERVICE.onrender.com
```

Valider manuellement le stage `Validation manuelle`.

## 9. Avant de zipper

Vérifier que ces dossiers/fichiers ne sont pas présents :

```txt
.git
node_modules
coverage
.DS_Store
__MACOSX
```
