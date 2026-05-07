# Infrastructure CI/CD QuickNotes

**Étudiant : Dylan Richardon**  
**Projet : QuickNotes — chaîne CI/CD Jenkins + Docker + Render + Discord**

## 1. Synthèse manager

La chaîne CI/CD mise en place permet de vérifier automatiquement l'application QuickNotes avant une mise en production.

Elle garantit les points suivants :

- le code est récupéré depuis un dépôt GitHub privé ;
- les dépendances sont installées de manière reproductible avec `npm ci` ;
- la qualité du code est contrôlée avec ESLint ;
- les tests unitaires sont exécutés automatiquement ;
- un seuil minimal de couverture est vérifié ;
- les dépendances sont auditées avec `npm audit` ;
- le code source est analysé avec Semgrep ;
- les secrets potentiellement exposés sont recherchés avec Gitleaks ;
- le déploiement Render est bloqué par une validation manuelle ;
- Jenkins notifie Discord en cas de succès, d'échec ou de résultat instable.

La pipeline évite donc le déploiement direct manuel par `scp` et apporte une traçabilité claire sur les contrôles qualité, sécurité et déploiement.

## 2. Schéma d'architecture

```txt
+-------------------+        git push        +----------------------+
| Poste développeur | ---------------------> | GitHub privé          |
| Dylan Richardon   |                        | eval-ci-cd-...        |
+-------------------+                        +----------+-----------+
                                                        |
                                                        | build manuel Jenkins
                                                        v
+-------------------------------------------------------+------------------+
| Jenkins local dans Docker                                                |
| - Job Pipeline depuis SCM Git                                             |
| - Credentials Jenkins                                                     |
| - Accès au Docker daemon de l'hôte                                         |
+----------------------+----------------------+--------------------------+
                       |
                       | stages isolés dans des conteneurs Docker dédiés
                       v
+----------------------+----------------------+--------------------------+
| Install | Lint | Tests | Coverage | SCA npm audit | SAST Semgrep | Gitleaks |
+----------------------+----------------------+--------------------------+
                       |
                       | validation manuelle
                       v
+----------------------+       Deploy Hook       +------------------------+
| Jenkins              | ----------------------> | Render Web Service     |
| Deploy - Render      |                         | Language Docker        |
+----------------------+                         +-----------+------------+
                                                          |
                                                          | /health = 200
                                                          v
                                                +------------------------+
                                                | API QuickNotes         |
                                                +------------------------+

+----------------------+
| Jenkins              |
| Notifications post   |
+----------+-----------+
           |
           | Webhook Discord
           v
+----------------------+
| Discord EPF Cyber    |
+----------------------+
```

## 3. Procédure d'installation Jenkins

### 3.1 Prérequis

- Docker Desktop installé et lancé ;
- `docker ps` fonctionnel ;
- Git installé ;
- compte GitHub ;
- compte Render ;
- accès au serveur Discord demandé.

### 3.2 Lancement Jenkins

Depuis la racine du projet :

#### Windows PowerShell

```powershell
.\scripts\start-jenkins.ps1
```

#### Linux/macOS

```bash
chmod +x ./scripts/start-jenkins.sh
./scripts/start-jenkins.sh
```

Jenkins est ensuite disponible sur :

```txt
http://localhost:8080
```

Le mot de passe initial est affiché par le script. Il peut aussi être récupéré avec :

```bash
docker exec -it jenkins-quicknotes cat /var/jenkins_home/secrets/initialAdminPassword
```

## 4. Plugins Jenkins nécessaires

- Git ;
- Pipeline ;
- Pipeline: Stage View ;
- Docker Pipeline ;
- Credentials Binding ;
- Workspace Cleanup ;
- Blue Ocean, facultatif mais pratique pour visualiser la pipeline.

## 5. Credentials Jenkins

Les secrets sont stockés dans Jenkins et ne sont pas écrits dans le code source.

| ID Jenkins | Type | Rôle |
|---|---|---|
| `github-token` | Username/password ou Secret text | Accès au dépôt GitHub privé |
| `discord-webhook` | Secret text | Envoi des notifications Discord |
| `render-deploy-hook` | Secret text | Déclenchement du déploiement Render |

## 6. Création du job Jenkins

```txt
New Item
→ Pipeline
→ Nom : quicknotes-ci-cd
→ Pipeline script from SCM
→ SCM : Git
→ Repository URL : dépôt GitHub privé
→ Credentials : github-token
→ Branch : main
→ Script Path : Jenkinsfile
```

## 7. Déclenchement choisi

Le build manuel est retenu.

Justification : Jenkins tourne localement dans un conteneur Docker sur un poste de travail. Un webhook GitHub ne peut pas joindre directement ce Jenkins sans exposer le poste sur Internet ou ajouter un tunnel. Pour l'évaluation, le build manuel est donc suffisant et plus simple à sécuriser.

Une alternative possible serait `pollSCM('* * * * *')`, mais ce choix interrogerait GitHub très fréquemment et n'apporte pas de valeur particulière dans ce contexte d'épreuve locale.

## 8. Description des stages Jenkins

| Stage | Rôle | Justification |
|---|---|---|
| Checkout | Récupère le code depuis GitHub. | Base de toute la pipeline. |
| Install | Lance `npm ci`. | Installation reproductible depuis `package-lock.json`. |
| Lint | Lance `npm run lint`. | Détecte les erreurs de style et de qualité JavaScript. |
| Tests | Lance `npm test`. | Vérifie le comportement de base de l'API. |
| Coverage | Lance Jest avec couverture. | Vérifie que les tests couvrent une partie suffisante du code. |
| SCA - npm audit | Analyse les dépendances. | Détecte les vulnérabilités connues dans les packages npm. |
| SAST - Semgrep | Analyse statique du code. | Détecte les failles applicatives comme une XSS. |
| Secrets - Gitleaks | Recherche les secrets. | Limite le risque de clés/API tokens exposés dans le dépôt. |
| Validation manuelle | Demande une confirmation humaine. | Empêche un déploiement automatique non contrôlé. |
| Deploy - Render | Déclenche le Deploy Hook Render. | Déploie l'application en mode Docker. |
| Healthcheck Render | Vérifie `/health`. | Confirme que l'application répond après déploiement. |

## 9. Seuil de couverture retenu

```json
{
  "global": {
    "lines": 70,
    "statements": 70,
    "functions": 50,
    "branches": 15
  }
}
```

Justification : le projet est court et dispose déjà de tests sur `/health` et `/time`. Le seuil doit être assez élevé pour éviter une absence de tests, mais pas trop strict car le projet contient une route volontairement vulnérable non testée. Lors de l'exécution locale, la couverture mesurée est d'environ 73 % sur les lignes et statements, 50 % sur les fonctions et 16 % sur les branches.

## 10. Outils de sécurité retenus

### npm audit

`npm audit` est utilisé pour l'analyse SCA. Il est intégré à npm, ne nécessite pas d'outil externe supplémentaire côté projet et détecte les vulnérabilités connues dans les dépendances.

### Semgrep

Semgrep est utilisé pour le SAST. Il est adapté à JavaScript/Node.js et peut utiliser à la fois des règles publiques et des règles personnalisées. Une règle locale `.semgrep/quicknotes.yml` est ajoutée pour détecter précisément la route `/welcome` vulnérable.

### Gitleaks

Gitleaks est utilisé pour la recherche de secrets. Il permet de détecter des tokens, clés API et secrets accidentellement présents dans le dépôt ou l'historique.

## 11. Isolation et reproductibilité des stages

Jenkins tourne dans un seul conteneur principal, mais les stages critiques s'exécutent chacun dans leur propre conteneur Docker :

- `node:20-alpine` pour Install, Lint, Tests, Coverage et SCA ;
- `semgrep/semgrep:latest` pour le SAST ;
- `ghcr.io/gitleaks/gitleaks:latest` pour la recherche de secrets.

Chaque stage refait un `checkout scm` dans un workspace propre et relance `npm ci` lorsque les dépendances sont nécessaires. Cela limite les effets de bord : un stage de tests ne laisse pas de fichiers ou dépendances pouvant influencer le stage Semgrep.

La reproductibilité est assurée par :

- `package-lock.json` ;
- `npm ci` au lieu de `npm install` ;
- images Docker dédiées ;
- nettoyage du workspace avec `cleanWs()` et `deleteDir()` ;
- absence de secrets en dur dans les fichiers versionnés.

## 12. Mode strict sécurité

Le `Jenkinsfile` contient un paramètre :

```txt
SECURITY_STRICT_MODE
```

- `true` : les stages SCA/SAST/Secrets bloquent réellement la pipeline. C'est le mode à utiliser pour obtenir les captures de stages rouges.
- `false` : les résultats de sécurité rendent la pipeline instable mais laissent la suite s'exécuter afin de tester le déploiement Render après documentation des failles.

Ce fonctionnement respecte la logique de l'épreuve : documenter les failles détectées puis autoriser temporairement la progression pour aller jusqu'au déploiement.

## 13. Déploiement Render

Le service Render doit être configuré en :

```txt
Language : Docker
Health Check Path : /health
```

Le `Dockerfile` fourni à la racine du projet est utilisé par Render pour construire l'application.

Le Deploy Hook Render est stocké dans Jenkins sous l'ID :

```txt
render-deploy-hook
```

L'URL Render publique doit être renseignée dans le paramètre Jenkins :

```txt
RENDER_APP_URL
```
