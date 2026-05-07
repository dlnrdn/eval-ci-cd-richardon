# Audit de sécurité QuickNotes

**Étudiant : Dylan Richardon**  
**Projet : QuickNotes — audit produit par la pipeline Jenkins**

## 1. Synthèse

La pipeline CI/CD a permis d'identifier plusieurs problèmes de sécurité dans l'application QuickNotes et son environnement projet.

Le code applicatif n'a pas été corrigé, conformément au périmètre demandé. Les vulnérabilités sont uniquement détectées et documentées.

## 2. Résultats exécutés localement

Les commandes suivantes ont été exécutées localement sur le projet fourni :

```bash
npm ci --ignore-scripts
npm run lint
npm test -- --coverage
npm audit --audit-level=low
```

Résultat observé :

- `npm run lint` : OK ;
- `npm test -- --coverage` : OK ;
- couverture : environ 73 % lignes/statements, 50 % fonctions, 16 % branches ;
- `npm audit` : 7 vulnérabilités détectées, dont 4 en criticité haute.

## 3. Tableau récapitulatif

| ID | Type | Localisation | Outil | Criticité | État |
|---|---|---|---|---|---|
| VULN-001 | XSS reflétée | `src/routes.js:17-20` | Semgrep | Haute | Détectée |
| VULN-002 | Dépendance vulnérable `path-to-regexp` | `package-lock.json` | npm audit | Haute | Détectée |
| VULN-003 | Dépendance vulnérable `qs` | `package-lock.json` | npm audit | Basse à modérée selon contexte | Détectée |
| VULN-004 | Dépendances de build vulnérables | `package-lock.json` | npm audit | Haute | Détectée |
| VULN-005 | Métadonnées Git et ancien workflow dans l'archive initiale | archive fournie | Revue manuelle / hygiène dépôt | Moyenne | Détectée |

---

## VULN-001 — XSS reflétée sur la route `/welcome`

| Champ | Valeur |
|---|---|
| Type | XSS reflétée |
| Localisation | `src/routes.js:17-20` |
| Outil détecteur | Semgrep, règle personnalisée `quicknotes.express.reflected-xss` |
| Extrait du code | `res.send(`<h1>Bienvenue, ${name}</h1>`)` |
| Criticité | Haute |
| Justification | La valeur `name` provient de `req.query.name` et est renvoyée directement dans une réponse HTML. Un attaquant peut construire un lien contenant du JavaScript injecté afin de l'exécuter dans le navigateur d'une victime. |
| Remédiation recommandée | Échapper la sortie HTML, utiliser un moteur de templates avec auto-escape ou retourner du JSON au lieu de HTML brut. |
| Capture attendue | `screenshots/03-pipeline-echec-sast.png` |

### Extrait de log attendu

```txt
quicknotes.express.reflected-xss
Entrée utilisateur provenant de req.query renvoyée dans une réponse HTML via res.send().
src/routes.js:20
```

---

## VULN-002 — Dépendance vulnérable `path-to-regexp`

| Champ | Valeur |
|---|---|
| Type | Dépendance vulnérable / Regular Expression Denial of Service |
| Localisation | `package-lock.json`, dépendance transitive d'Express |
| Outil détecteur | npm audit |
| Extrait du log | `path-to-regexp vulnerable to Denial of Service via sequential optional groups` |
| Criticité | Haute |
| Justification | `path-to-regexp` est utilisé dans l'écosystème Express pour la gestion des routes. Une vulnérabilité ReDoS peut provoquer une consommation excessive de ressources via des chemins spécialement construits. |
| Remédiation recommandée | Mettre à jour les dépendances avec `npm audit fix`, vérifier la version d'Express et valider la non-régression avec les tests. |
| Capture attendue | `screenshots/02-pipeline-echec-sca.png` |

### Extrait de log observé

```txt
path-to-regexp  8.0.0 - 8.3.0
Severity: high
path-to-regexp vulnerable to Denial of Service via sequential optional groups
path-to-regexp vulnerable to Regular Expression Denial of Service via multiple wildcards
fix available via `npm audit fix`
node_modules/path-to-regexp
```

---

## VULN-003 — Dépendance vulnérable `qs`

| Champ | Valeur |
|---|---|
| Type | Dépendance vulnérable / Denial of Service |
| Localisation | `package-lock.json`, dépendance transitive |
| Outil détecteur | npm audit |
| Extrait du log | `qs's arrayLimit bypass in comma parsing allows denial of service` |
| Criticité | Basse à modérée selon exposition réelle |
| Justification | `qs` sert au parsing de paramètres. Une faille de parsing peut faciliter une attaque par déni de service si l'application expose des entrées utilisateur complexes. |
| Remédiation recommandée | Mettre à jour `qs` via les dépendances parentes, vérifier le lockfile et relancer les tests. |
| Capture attendue | `screenshots/02-pipeline-echec-sca.png` |

### Extrait de log observé

```txt
qs  6.7.0 - 6.14.1
qs's arrayLimit bypass in comma parsing allows denial of service
fix available via `npm audit fix`
node_modules/qs
```

---

## VULN-004 — Dépendances de build vulnérables

| Champ | Valeur |
|---|---|
| Type | Vulnérabilités dans les dépendances de développement et de build |
| Localisation | `package-lock.json` |
| Outil détecteur | npm audit |
| Extrait du log | `minimatch`, `picomatch`, `flatted`, `ajv`, `brace-expansion` |
| Criticité | Haute pour certaines dépendances |
| Justification | Même si certaines dépendances sont liées au build ou aux tests, elles restent exécutées dans la chaîne CI/CD. Une dépendance vulnérable dans l'outillage peut fragiliser l'environnement de build. |
| Remédiation recommandée | Mettre à jour les dépendances de développement, supprimer les packages obsolètes, relancer lint/tests/coverage après correction. |
| Capture attendue | `screenshots/02-pipeline-echec-sca.png` |

### Extrait de log observé

```txt
flatted  <=3.4.1
Severity: high
flatted vulnerable to unbounded recursion DoS in parse() revive phase
Prototype Pollution via parse() in NodeJS flatted

minimatch  <=3.1.3 || 9.0.0 - 9.0.6
Severity: high
minimatch has a ReDoS via repeated wildcards

picomatch  <=2.3.1 || 4.0.0 - 4.0.3
Severity: high
Picomatch has a ReDoS vulnerability via extglob quantifiers
```

---

## VULN-005 — Métadonnées Git et ancien workflow dans l'archive initiale

| Champ | Valeur |
|---|---|
| Type | Hygiène dépôt / exposition d'historique et de métadonnées |
| Localisation | archive initiale fournie, dossiers `.git/`, `__MACOSX/`, `.DS_Store`, ancien `.github/workflows/ci.yml` |
| Outil détecteur | Revue manuelle, contrôle d'archive, Gitleaks selon historique |
| Extrait constaté | Présence d'un dossier `.git` complet et d'un remote GitHub dans `.git/config` |
| Criticité | Moyenne |
| Justification | Un dossier `.git` ne doit pas être livré dans une archive de rendu. Il peut exposer l'historique, les branches, les remotes, d'anciens fichiers supprimés et parfois des secrets retirés du code courant mais encore présents dans l'historique. |
| Remédiation recommandée | Supprimer `.git`, `node_modules`, `coverage`, `.DS_Store`, `__MACOSX` avant le rendu. Créer un nouveau dépôt propre pour l'évaluation. |
| Capture attendue | Capture facultative de l'arborescence nettoyée ou résultat Gitleaks |

## 4. Captures à ajouter

Les captures réelles doivent être ajoutées dans `screenshots/` :

| Capture | Contenu attendu |
|---|---|
| `01-jenkins-job.png` | Job Jenkins configuré en Pipeline from SCM |
| `02-pipeline-echec-sca.png` | Stage `SCA - npm audit` en échec ou instable |
| `03-pipeline-echec-sast.png` | Stage `SAST - Semgrep` signalant la XSS |
| `04-pipeline-echec-secrets.png` | Stage `Secrets - Gitleaks` |
| `05-render-deploy.png` | Service Render déployé en Docker |
| `06-discord-notification.png` | Notification Discord reçue |

## 5. Conclusion

La pipeline détecte correctement les problèmes principaux : une faille applicative de type XSS, plusieurs dépendances vulnérables et des problèmes d'hygiène de dépôt. Le déploiement ne doit être validé qu'après documentation des failles dans ce rapport et confirmation manuelle dans Jenkins.
