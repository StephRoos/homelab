---
title: "Homelab — OpenClaw + Vibe CLI · Architecture hybride"
tags: [homelab, openclaw, vibe, automatisation, telegram]
---

# Homelab — OpenClaw + Vibe CLI · Architecture hybride

## 00 - Architecture hybride
*Concept · Comprendre avant d'installer*
OpenClaw (routeur léger) + Vibe CLI -p (moteur d'exécution)

### Comprendre le flux de données `Concept`

> L'idée : OpenClaw avec Haiku 4.5 (~0.001$/message) comprend tes commandes Telegram et choisit le bon skill. Le skill lance **vibe -p** dans le bon répertoire. Vibe CLI (Mistral, plan Pro) travaille dans le codebase avec tout le contexte.

```
Flux d'une commande
 
 📱 Telegram
 →
 🦞 OpenClaw
Haiku 4.5 (API)
 →
 ⚡ Vibe CLI -p
Mistral (Pro)
 →
 ✅ Résultat
→ Telegram
```

| Composant | Rôle | Facturation | Coût estimé |
| --- | --- | --- | --- |
| OpenClaw + Haiku 4.5 | Routeur : comprend la commande, choisit le skill | API au token (1$/M in, 5$/M out) | ~5-10$/mois |
| Vibe CLI -p | Moteur : lit le code, édite, teste, commit | Inclus dans abonnement Pro | 20$/mois (fixe) |
| Telegram Bot API | Interface de commande | Gratuit | 0$ |

> **Attention** : Alternative économique : Plan Gratuit + extra usage plafonné. Si ton usage de Vibe CLI headless est modéré, Gratuit + Haiku API ≈ 10-15$/mois.

### Pourquoi Vibe CLI -p plutôt que l'API brute `Vibe CLI`

- 1. Vibe CLI **lit automatiquement les fichiers** du projet et comprend la structure du repo.
- 2. Il peut **éditer du code, lancer des tests, faire des commits** — l'API brute ne fait que du texte.
- 3. Il lit **VIBE.md** à la racine du projet pour comprendre le contexte, la stack, les conventions.
- 4. Le flag `--allowedTools` restreint précisément ce que Vibe CLI a le droit de faire (lecture seule, écriture, shell...).
- 5. Le flag `--max-turns` limite les itérations pour éviter les boucles coûteuses.
- 6. Les sessions sont **reprenables** avec `--resume` pour les tâches multi-étapes.


## 01 - Node.js 24 & Vibe CLI
*Installation · ~15 min*
nvm · npm · authentification API

### Installer nvm et Node.js 24 `UM790 (SSH)`

**SSH homelab — installer Node**
```bash
# Installer nvm
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash
source ~/.bashrc

# Installer et activer Node 24
nvm install 24
nvm use 24
nvm alias default 24

# Vérifier
node -v # → v24.x.x
npm -v # → 10.x.x
```

### Installer et authentifier Vibe CLI `Vibe CLI`

**SSH homelab — Vibe CLI**
```bash
# Installer Vibe CLI globalement
npm install -g @mistralai/vibe

# Vérifier
vibe --version

# Authentifier avec ta clé API Mistral
vibe auth login

# Tester le mode headless
vibe -p "Dis bonjour" --output json
```

> Vibe CLI utilise ton abonnement Mistral (Pro ou Gratuit). L'auth se fait via clé API. Le token est stocké dans `~/.vibe/`. C'est séparé de la clé API d'OpenClaw.

### Installer et authentifier GitHub CLI (gh) `GitHub`

> GitHub CLI permet de créer des issues, PRs et gérer les repos depuis le terminal. Les skills OpenClaw l'utiliseront pour transformer automatiquement chaque recommandation de Vibe CLI en issue GitHub.

**SSH homelab — GitHub CLI**
```bash
# Installer gh (GitHub CLI)
curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | \
 sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | \
 sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null
sudo apt update && sudo apt install gh -y

# Vérifier
gh --version

# Authentifier (une seule fois)
gh auth login
# → Choisir GitHub.com → HTTPS → Authenticate with browser
# → Copier le code, ouvrir le lien sur ton Mac, coller le code

# Tester
gh auth status
gh repo list --limit 5
```

> Pour l'auth headless (sans navigateur sur le serveur), utilise un **Personal Access Token** : sur github.com → Settings → Developer Settings → Personal Access Tokens → Generate. Puis : `echo "TON_TOKEN" | gh auth login --with-token`


## 02 - OpenClaw & configuration Haiku
*Installation · ~10 min*
Routeur léger · Haiku 4.5 · systemd

### Installer OpenClaw `OpenClaw`

**SSH homelab — OpenClaw**
```bash
# Méthode 1 : Script one-liner (recommandé)
curl -fsSL https://openclaw.ai/install.sh | bash

# Méthode 2 : Via npm
npm install -g openclaw@latest
openclaw onboard --install-daemon

# Vérifier
openclaw --version
openclaw doctor
openclaw gateway status
```

> Le flag `--install-daemon` crée un service systemd qui démarre automatiquement au boot. Logs : `journalctl -u openclaw --follow`

### Configurer Haiku 4.5 comme LLM (routeur léger) `OpenClaw`

**~/.openclaw/openclaw.json — provider**
```json
{
 "providers": {
 "anthropic": {
 "apiKey": "sk-ant-api03-TA_CLE_API_ICI"
 }
 },
 "agents": {
 "defaults": {
 "model": "anthropic/claude-haiku-4-5"
 }
 }
}
```

> **Attention** : La clé API ici (console.anthropic.com) est uniquement pour le routeur Haiku d'OpenClaw. Claude Code utilise ton abonnement Max séparément. Mets un plafond mensuel sur ton compte API.


## 03 - Connecter Telegram
*Canal · ~5 min*
BotFather · Token · Pairing · Sécurité

### Créer le bot Telegram `Telegram`

- 1. Ouvrir Telegram → chercher **@BotFather** (compte vérifié ✓).
- 2. Envoyer `/newbot` → suivre les instructions (nom + identifiant finissant par `bot`).
- 3. Copier le **token** généré (format : `123456789:ABCdef...`).
- 4. Récupérer ton **user ID** en envoyant un message à **@userinfobot**.

### Configurer le canal et pairing `OpenClaw`

**~/.openclaw/openclaw.json — channels**
```json
{
 "channels": {
 "telegram": {
 "enabled": true,
 "botToken": "123456789:ABCdefGHIjklMNOpqrsTUVwxyz",
 "dmPolicy": "pairing",
 "groups": { "*": { "requireMention": true } }
 }
 }
}
```

**SSH — Appliquer et pairer**
```bash
openclaw gateway restart
openclaw channels status

# Ensuite : ouvre Telegram → ton bot → Start → envoie "hello"
# Le bot répond avec un code de pairing

openclaw pairing approve telegram Z2EDQKMK
```

> **Resultat** : ✅ Test : Envoie un message à ton bot sur Telegram. S'il répond, tout est connecté.

### Sécuriser l'installation `Sécurité`

- 1. **Ne jamais exposer** le port 18789 sans authentification. Utiliser Cloudflare Access (phase 03b) ou SSH tunnel.
- 2. Fallback local : `ssh -L 18789:localhost:18789 homelab`
- 3. Vérifier : `openclaw doctor`
- 4. Garder `dmPolicy` sur `"pairing"` ou `"allowlist"`.
- 5. Limiter les `--allowedTools` dans chaque skill pour le moindre privilège.


## 03b - Control UI via Cloudflare Tunnel
*Accès remote · Alternative à Telegram · ~10 min*
Accéder au WebChat OpenClaw depuis ton PC de bureau en remote

### Comprendre les options d'accès remote `Concept`

> Tu as déjà un Cloudflare Tunnel configuré sur ton UM790. Il suffit d'ajouter une route vers le Control UI d'OpenClaw, protégée par Cloudflare Access. Résultat : tu tapes `openclaw.tondomain.com` dans le navigateur de ton PC au bureau et tu as le chat + dashboard complet.

| Méthode | Setup | Avantages | Inconvénients |
| --- | --- | --- | --- |
| Cloudflare Tunnel + Access | Tu l'as déjà ✓ | Fonctionne partout, auth par email, HTTPS auto | Dépend de Cloudflare |
| Tailscale Serve | Installer Tailscale sur les 2 machines | Zero-config, VPN chiffré, gratuit | Client à installer partout |
| SSH Tunnel | Rien à installer | Le plus sécurisé, universel | Terminal SSH ouvert en permanence |
| Telegram | Déjà configuré ✓ | Mobile, notifications push | Rendu limité, pas de dashboard |

> **Recommandation :** Cloudflare Tunnel pour le PC de bureau (navigateur) + Telegram pour le mobile. Les deux en parallèle, même assistant, mêmes skills.

### Ajouter la route dans Cloudflare Tunnel `Cloudflare`

- 1. Aller sur **one.dash.cloudflare.com** → ton compte → Networks → Tunnels.
- 2. Cliquer sur ton tunnel **homelab** → Configure → Public Hostname → **Add a public hostname**.
- 3. Remplir :

 `Subdomain:` **openclaw**

 `Domain:` **tondomain.com**

 `Type:` **HTTP**

 `URL:` **localhost:18789**
- 4. Sauvegarder. Le sous-domaine `openclaw.tondomain.com` pointe maintenant vers le gateway local.

> **Attention** : Sans la protection Access (étape suivante), le Control UI serait accessible à tout internet. Ne pas s'arrêter ici.

### Protéger avec Cloudflare Access (Zero Trust) `Sécurité`

- 1. Dans le dashboard Zero Trust → **Access → Applications → Add an application**.
- 2. Choisir **Self-hosted**.
- 3. Configurer :

 `Application name:` **OpenClaw**

 `Session duration:` **24 hours** (ou plus)

 `Application domain:` **openclaw.tondomain.com**
- 4. **Add a policy** (qui peut accéder) :

 `Policy name:` **Only me**

 `Action:` **Allow**

 `Include → Emails:` **[email]**
- 5. Sauvegarder. Cloudflare envoie un code par email à chaque connexion.

> Résultat : quand tu ouvres `https://openclaw.tondomain.com` depuis n'importe où, Cloudflare demande ton email → t'envoie un code → tu es connecté au Control UI complet avec chat, config, logs, et gestion des skills.

### Configurer le gateway token pour le WebChat `OpenClaw`

**~/.openclaw/openclaw.json — gateway auth**
```json
{
 "gateway": {
 "auth": {
 "mode": "token",
 "token": "GENERE_UN_TOKEN_ALEATOIRE"
 },
 "controlUi": {
 "enabled": true
 }
 }
}
```

**Générer un token sécurisé**
```bash
# Générer un token aléatoire
openssl rand -hex 32

# Redémarrer le gateway
openclaw gateway restart
```

- 1. Ouvrir `https://openclaw.tondomain.com` dans le navigateur.
- 2. S'authentifier via Cloudflare Access (code email).
- 3. Dans le Control UI → Settings → coller le **gateway token**.
- 4. Approuver le device : `openclaw devices approve <requestId>` (une seule fois).
- 5. Cliquer sur **WebChat** → envoyer un message → l'agent répond.

> **Resultat** : ✅ Double sécurité : Cloudflare Access (auth email) + Gateway token (auth OpenClaw). Deux couches indépendantes.

### Ce que tu peux faire depuis le Control UI `Fonctions`

| Fonction | Description | Avantage vs Telegram |
| --- | --- | --- |
| 💬 WebChat | Chat avec l'agent, streaming temps réel | Rendu Markdown riche, blocs de code |
| ⚙️ Config | Éditer openclaw.json en live avec validation | Pas besoin de SSH pour modifier |
| 📊 Sessions | Voir toutes les sessions, historique, coûts | Vue d'ensemble impossible sur Telegram |
| 🔧 Tools | Tester les outils disponibles | Debug interactif |
| 📋 Logs | Tail en temps réel avec filtres | Pas besoin de journalctl |
| 🧩 Skills | Voir et gérer les skills installés | Vue complète du système |
| 🔄 Update | Mettre à jour OpenClaw depuis le navigateur | Un clic au lieu de SSH + npm |

> **Les deux canaux coexistent :** les messages envoyés via le WebChat et ceux envoyés via Telegram arrivent au même agent, avec la même mémoire et les mêmes skills. Tu peux commencer une tâche sur le WebChat au bureau et la suivre sur Telegram dans le métro.


## 04 - Workspace & VIBE.md
*Structure · ~10 min*
Repos · Structure · Contexte par projet

### Créer la structure et cloner les repos `Workspace`

**SSH homelab — Structure**
```bash
mkdir -p ~/openclaw/workspace/{projects,skills,scripts}
mkdir -p ~/openclaw/workspace/scripts/{daily,deploy,git}

# Cloner tes repos
cd ~/openclaw/workspace/projects
git clone [email]:ton-user/projet-saas.git
git clone [email]:ton-user/site-client.git
git clone [email]:ton-user/api-interne.git

# Config git
git config --global user.name "Ton Nom"
git config --global user.email "[email]"
```

### Ajouter VIBE.md dans chaque projet `Vibe CLI`

> Vibe CLI lit automatiquement `VIBE.md` à la racine du projet. Il donne le contexte complet : stack, architecture, conventions, commandes. Ça rend le mode `-p` beaucoup plus efficace.

**projects/projet-saas/VIBE.md (template)**
```markdown
# VIBE.md — Projet SaaS

## Stack
- Backend: Node.js 22 + Express + TypeScript
- Frontend: React 19 + Vite + TailwindCSS
- Database: PostgreSQL 16 via Prisma ORM
- Tests: Vitest + Playwright

## Architecture
src/
 routes/ # Express routes
 services/ # Business logic
 models/ # Prisma models
 middleware/ # Auth, validation

## Conventions
- Conventional commits (feat:, fix:, refactor:)
- Pas de console.log en prod
- TypeScript strict mode
- Variables d'env dans .env

## Commandes
- npm run dev # serveur de dév
- npm test # tests unitaires
- npm run build # build prod
```


## 05 - 6 Skills personnalisés
*Skills hybrides · OpenClaw → Claude Code -p*
project-status · git-workflow · code-review · code-task · deploy · github-issues

### Skill : Project Status `Skill`

**skills/project-status/SKILL.md**
```markdown
---
name: project-status
description: >
 Scanne tous les projets et génère un rapport complet 
 via Claude Code qui analyse chaque repo en profondeur.
triggers:
 - "statut projets"
 - "project status"
 - "où en sont mes projets"
---

# Project Status (via Claude Code)

Pour chaque dossier dans ~/openclaw/workspace/projects/
contenant un .git, exécuter :

```bash
cd ~/openclaw/workspace/projects/<projet>
claude -p "Analyse ce projet : branche courante,
 3 derniers commits, fichiers modifiés non committés,
 TODO.md si présent. Résumé concis avec emojis." \
 --allowedTools "Read,Grep,Glob,Bash(git:*)" \
 --output-format json \
 --max-turns 5
```

Agréger les résultats en un rapport unifié.
```

### Skill : Git Workflow `Skill`

**skills/git-workflow/SKILL.md**
```markdown
---
name: git-workflow
description: >
 Gère le workflow Git via Claude Code : créer des 
 branches, committer, pousser, préparer des merges.
triggers:
 - "crée une branche"
 - "pousse le code"
 - "committe"
 - "prépare un merge"
---

# Git Workflow (via Claude Code)

## Créer une branche
```bash
cd ~/openclaw/workspace/projects/<projet>
claude -p "Crée une branche <type>/<desc> depuis
 main à jour. Vérifie que main est pullé avant." \
 --allowedTools "Bash(git:*)" \
 --max-turns 5
```

## Committer et pousser
```bash
claude -p "Regarde les modifications, propose un 
 message conventional commits, committe et pousse." \
 --allowedTools "Read,Bash(git:*)" \
 --max-turns 5
```

## Règles strictes
- JAMAIS de push --force sans confirmation
- JAMAIS de commit direct sur main
- Toujours pull main avant de créer une branche
```

### Skill : Code Review (le plus puissant) `Skill`

> C'est ici que l'architecture hybride brille. Vibe CLI lit tout le diff **et** comprend le contexte du projet via VIBE.md. **Chaque finding est automatiquement transformé en issue GitHub.**

**skills/code-review/SKILL.md**
```markdown
---
name: code-review
triggers: ["review le code", "code review", "est-ce que je peux merger"]
---

# Code Review + Issues GitHub

## Procédure
```bash
cd ~/openclaw/workspace/projects/<projet>
claude -p "Tu es un reviewer senior. Analyse le diff
 de la branche courante vs origin/main.
 
 Vérifie :
 1. Bugs potentiels et erreurs logiques
 2. Failles de sécurité (secrets exposés...)
 3. Qualité du code (nommage, duplication)
 4. Tests manquants
 5. Breaking changes
 
 Score de confiance (0-100%) et verdict :
 ✅ SAFE TO MERGE (90-100%)
 ⚠️ REVIEW NEEDED (60-89%)
 ❌ NEEDS WORK (0-59%)
 
 IMPORTANT — Pour chaque finding ⚠️ ou ❌ :
 Crée une issue GitHub avec gh issue create :
 
 gh issue create \
 --title '[review] Description courte du problème' \
 --body 'Trouvé lors du code review de BRANCHE.
 
 **Fichier:** chemin/fichier.ts:LIGNE
 **Sévérité:** ⚠️ WARNING ou ❌ CRITICAL
 **Description:** Explication détaillée...
 **Suggestion:** Comment corriger...' \
 --label 'review,BRANCHE'
 
 Assigner les labels : 'bug' si c'est un bug,
 'security' si c'est une faille, 'enhancement' sinon.
 
 Format compact pour Telegram avec liens des issues." \
 --allowedTools "Read,Grep,Glob,Bash(git:*,gh:*)" \
 --max-turns 20
```

## Avantage
Chaque recommandation est traçable dans GitHub.
Les issues peuvent être assignées, priorisées et
suivies indépendamment du chat Telegram.
```

### Skill : Code Task (développer depuis Telegram) `Skill`

> **Note** : Ce skill permet de coder depuis Telegram sans accès terminal. **Sécurité : refuse d'écrire si la branche est main.**

**skills/code-task/SKILL.md**
```markdown
---
name: code-task
triggers: ["implémente", "code", "ajoute", "fixe le bug", "refactorise"]
---

# Code Task — Mode sécurisé (branche obligatoire)

```bash
cd ~/openclaw/workspace/projects/<projet>

# SÉCURITÉ : vérifier qu'on n'est PAS sur main
BRANCH=$(git branch --show-current)
if [ "$BRANCH" = "main" ]; then
 echo "❌ Refusé : créer une branche d'abord"
 exit 1
fi

claude -p "<instruction utilisateur>
 Règles :
 - Travaille uniquement sur la branche courante
 - Lance les tests après modification
 - Committe avec conventional commits
 - Référence les issues dans le commit (closes #XX)
 - Pousse sur la branche
 - Si tu détectes un problème non lié, crée une issue
 GitHub avec gh issue create au lieu de le corriger" \
 --allowedTools "Read,Edit,Write,Bash,Grep,Glob" \
 --max-turns 25
```

# Sessions multi-étapes
```bash
claude -p "Étape 1" --output-format json > /tmp/r.json
SESSION=$(jq -r '.session_id' /tmp/r.json)
claude --resume "$SESSION" -p "Étape 2"
```
```

### Skill : Deploy `Skill`

**skills/deploy/SKILL.md**
```markdown
---
name: deploy
triggers: ["déploie", "deploy", "mets en prod"]
---

```bash
cd ~/openclaw/workspace/projects/<projet>
claude -p "Vérifie : on est sur main, pas de modifs
 non committées, main à jour avec origin.
 Si OK → déploie via Coolify API.
 Attends 30s → vérifie le health check.
 Rapporte le résultat." \
 --allowedTools "Read,Bash(git:*,curl:*)" \
 --max-turns 10
```
```

**Créer tous les dossiers skills**
```bash
mkdir -p ~/openclaw/workspace/skills/{project-status,git-workflow,code-review,code-task,deploy,github-issues}
```

### Skill : GitHub Issues (gestion complète) `GitHub`

> **Principe :** chaque recommandation de Claude sur un projet doit faire l'objet d'une issue GitHub. Ce skill gère la création, la consultation et la fermeture des issues depuis Telegram.

**skills/github-issues/SKILL.md**
```markdown
---
name: github-issues
description: >
 Gère les issues GitHub depuis Telegram : créer, lister,
 fermer, assigner. Chaque recommandation de Claude Code
 génère automatiquement une issue traçable.
triggers:
 - "crée une issue"
 - "issues ouvertes"
 - "liste les issues"
 - "ferme l'issue"
 - "issues github"
 - "quelles issues"
 - "bug sur"
---

# GitHub Issues Manager (via Claude Code + gh)

## Règle fondamentale
Toute recommandation, bug détecté, amélioration suggérée,
ou dette technique identifiée par Claude Code DOIT être
transformée en issue GitHub. Pas d'exception.

## Créer une issue
```bash
cd ~/openclaw/workspace/projects/<projet>
claude -p "Crée une issue GitHub pour : <description>

 Utilise gh issue create avec :
 --title : titre clair et concis, préfixé par le type
 [bug] / [feat] / [refactor] / [security] / [debt]
 --body : description détaillée en Markdown avec :
 - Contexte (quelle partie du code)
 - Problème ou besoin
 - Suggestion de solution
 - Fichiers concernés si connus
 --label : labels appropriés parmi :
 bug, enhancement, security, tech-debt, 
 review, documentation, priority:high/medium/low

 Confirme la création avec le numéro d'issue." \
 --allowedTools "Read,Grep,Bash(gh:*,git:*)" \
 --max-turns 5
```

## Lister les issues ouvertes
```bash
claude -p "Liste les issues ouvertes de ce repo.
 Utilise : gh issue list --state open
 Résumé concis avec # + titre + labels.
 Groupe par priorité si des labels priority: existent." \
 --allowedTools "Bash(gh:*)" \
 --max-turns 3
```

## Fermer une issue
```bash
claude -p "Ferme l'issue #<num> avec un commentaire
 expliquant la résolution.
 gh issue close <num> --comment 'Résolu dans <commit>'" \
 --allowedTools "Bash(gh:*,git log:*)" \
 --max-turns 3
```

## Audit complet (créer des issues en masse)
```bash
claude -p "Fais un audit complet de ce projet.
 Pour CHAQUE problème trouvé, crée une issue GitHub.
 
 Catégories à analyser :
 1. Sécurité (secrets, injections, permissions)
 2. Bugs potentiels (null checks, race conditions)
 3. Dette technique (code dupliqué, TODO/FIXME)
 4. Tests manquants
 5. Documentation manquante
 
 Crée une issue par finding avec gh issue create.
 Résumé final : nombre d'issues créées par catégorie." \
 --allowedTools "Read,Grep,Glob,Bash(gh:*,git:*)" \
 --max-turns 30
```
```


## 06 - Scripts & tâches planifiées
*Automatisation · Cron + scripts intelligents*
Rapport quotidien · Pré-merge · Merge complet

### Rapport quotidien intelligent (cron + Claude Code) `Cron`

**scripts/daily/smart-report.sh**
```bash
#!/bin/bash
PROJECTS_DIR="$HOME/openclaw/workspace/projects"
REPORT=""

for dir in "$PROJECTS_DIR"/*/; do
 if [ -d "$dir/.git" ]; then
 name=$(basename "$dir")
 ANALYSIS=$(cd "$dir" && claude -p "Résumé ultra-concis
 (3 lignes max) : branche, dernier commit, statut,
 problèmes éventuels. Format: emoji + texte." \
 --allowedTools "Read,Grep,Bash(git:*)" \
 --max-turns 3 --bare 2>/dev/null)
 REPORT+="\n📁 $name\n$ANALYSIS\n"
 fi
done

echo -e "📊 RAPPORT $(date +%d/%m/%Y)\n$REPORT"
```

**Activer**
```bash
chmod +x ~/openclaw/workspace/scripts/daily/smart-report.sh

# Via Telegram :
# /cron add morning-report "0 8 * * 1-5" \
# "~/openclaw/workspace/scripts/daily/smart-report.sh"
```

> Le flag `--bare` saute le chargement des hooks, skills, plugins et VIBE.md. Il accélère le démarrage pour les tâches légères comme le rapport.

### Script pré-merge intelligent `Git`

**scripts/git/smart-pre-merge.sh**
```bash
#!/bin/bash
# Usage: ./smart-pre-merge.sh <projet> [branche]
PROJECT=$1; BRANCH=$2
DIR="$HOME/openclaw/workspace/projects/$PROJECT"
cd "$DIR" || { echo "❌ Projet introuvable"; exit 1; }
[ -z "$BRANCH" ] && BRANCH=$(git branch --show-current)
[ "$BRANCH" = "main" ] && { echo "❌ Déjà sur main"; exit 1; }

echo "🔍 Analyse : $BRANCH → main"
claude -p "Analyse complète pour merger $BRANCH → main :
 1. Liste les commits (git log origin/main..$BRANCH)
 2. Fichiers modifiés (git diff --stat)
 3. Test conflits (merge --no-commit --no-ff, puis abort)
 4. Vérifie : pas de secrets, pas de console.log, tests ok
 5. Verdict : ✅ SAFE / ⚠️ REVIEW / ❌ NEEDS WORK
 Format compact pour Telegram." \
 --allowedTools "Read,Grep,Glob,Bash(git:*)" \
 --max-turns 15
```

### Script merge complet `Git`

**scripts/git/merge-to-main.sh**
```bash
#!/bin/bash
# Usage: ./merge-to-main.sh <projet> [branche]
PROJECT=$1; BRANCH=$2
DIR="$HOME/openclaw/workspace/projects/$PROJECT"
cd "$DIR" || exit 1
[ -z "$BRANCH" ] && BRANCH=$(git branch --show-current)
[ "$BRANCH" = "main" ] && { echo "❌ Déjà sur main"; exit 1; }

# Vérifier modifications non committées
[ -n "$(git status --porcelain)" ] && \
 { echo "❌ Modifications non committées"; exit 1; }

echo "🔀 Merge : $BRANCH → main"
git checkout main
git pull origin main
git merge --no-ff "$BRANCH" -m "merge: $BRANCH into main"
[ $? -ne 0 ] && { echo "❌ Conflits détectés"; exit 1; }

git push origin main
git branch -d "$BRANCH"
git push origin --delete "$BRANCH" 2>/dev/null

echo "✅ $BRANCH fusionnée et supprimée"
echo " HEAD: $(git log --oneline -1)"
```

**Permissions**
```bash
chmod +x ~/openclaw/workspace/scripts/git/*.sh
chmod +x ~/openclaw/workspace/scripts/daily/*.sh
```


## 07 - Lifecycle d'une feature
*Workflow complet · De A à Z*
Création → Dev → Review → Merge → Deploy

### Exemple complet : feature/auth-google `Workflow`

**① Créer la branche (Telegram, dans le métro)**

> **Toi** : Crée une branche feature/auth-google sur projet-saas
> **Bot** :
> ✅ Branche **feature/auth-google** créée
> Base: abc1234 - Last commit on main (il y a 3h)

**② Développer (deux options)**

> **Option A (bureau) :** `ssh homelab` → `cd projet-saas` → `claude` (mode interactif)
**Option B (mobile) :** Via Telegram → Claude Code -p fait le travail

> **Toi (Telegram)** : Sur projet-saas, implémente Google OAuth avec passport-google-oauth20
> **Bot (Claude Code -p)** :
> 🔧 Tâche en cours sur feature/auth-google...
> 
> ✅ Implémenté et committé :
> `feat: add Google OAuth 2.0 authentication`
> 4 fichiers modifiés | +183 -8 | Tests: 12/12 ✔

**③ Code Review + Issues GitHub (Telegram)**

> **Toi** : Review feature/auth-google sur projet-saas
> **Bot (Claude Code -p + gh)** :
> 🔍 **Code Review** · 4 fichiers · +183 -8
> 
> Score: **87% — REVIEW NEEDED**
> 
> ⚠️ client_secret en dur dans config.ts:23
> → **Issue #42 créée** `[security] OAuth secret hardcoded`
> 
> 💡 Test manquant pour callback token expiré
> → **Issue #43 créée** `[enhancement] Add expired token test`
> 
> ✅ Architecture conforme à VIBE.md
> ✅ Pas de breaking changes
> 
> 📋 2 issues créées · `gh issue list --label review`

**④ Corriger les issues (Telegram)**

> **Toi** : Fixe les issues #42 et #43 sur projet-saas
> **Bot** :
> ✅ Corrections committées et poussées :
> `fix: move OAuth secret to env vars (closes #42)`
> `test: add expired token callback test (closes #43)`
> 
> Issues #42 et #43 fermées automatiquement au merge.

### Flow de branches (diagramme) `Git flow`

**Branching model**
```
main ○───○─────────────────────────────────○───○ (deploy)
 │ \ / │
 │ ○──○──○──○──○──────────○ / │
 │ feature/auth-google │ / │
 │ │/ │
 │ [① créer] [② coder] [③ review+issues]
 │ Telegram CC -p Telegram + gh
 │ ou SSH crée issues auto
 │ │
 │ ┌───────┴────────┐
 │ │ GitHub Issues │
 │ │ #42 #43 créées │
 │ │ par le review │
 │ └───────┬────────┘
 │ │
 │ [④ fix closes #42 #43]
 │ │
 pull merge → deploy
 (cron) (Telegram)

┌────────────────────────────────────────────────┐
│ Règles absolues : │
│ 1. On ne code JAMAIS sur main │
│ 2. Claude Code -p refuse si branch=main │
│ 3. Chaque finding = une issue GitHub │
│ 4. Merge après review + pre-merge check │
│ 5. Commits référencent les issues (closes #) │
│ 6. Deploy uniquement depuis main propre │
└────────────────────────────────────────────────┘
```


## 08 - Flags et patterns essentiels
*Référence · Claude Code -p*
--allowedTools · --max-turns · --resume · --bare

### Tableau des flags `Référence`

| Flag | Usage | Exemple |
| --- | --- | --- |
| -p <prompt> | Mode non-interactif | claude -p "Analyse ce code" |
| --output-format json | Sortie structurée (session_id, cost...) | Pour parsing dans scripts |
| --allowedTools | Restreindre les outils | "Read,Grep,Glob" (lecture seule) |
| --disallowedTools | Interdire des outils | "Write,Edit" (pas de modif) |
| --max-turns N | Limiter les itérations | 10 (review), 25 (implémentation) |
| --continue | Continuer la dernière session | Suivi multi-étapes |
| --resume <id> | Reprendre une session spécifique | Avec session_id du JSON |
| --bare | Skip plugins/hooks/VIBE.md | Tâches rapides et légères |
| --append-system-prompt | Ajouter au prompt système | Rôle spécifique (reviewer...) |

### Patterns de permissions par contexte `Référence`

**Patterns --allowedTools**
```bash
# Lecture seule (analyse, status)
--allowedTools "Read,Grep,Glob"

# Lecture + git (review avec historique)
--allowedTools "Read,Grep,Glob,Bash(git diff:*,git log:*,git status:*)"

# Écriture complète (implémentation)
--allowedTools "Read,Edit,Write,Bash,Grep,Glob"

# Déploiement (git + curl uniquement)
--allowedTools "Read,Bash(git:*,curl:*)"
```


## 09 - Checklist d'installation
*Checklist · 19 étapes*
Tout ce qu'il faut faire ce soir, dans l'ordre

### Liste complète `Checklist`

| # | Action | Vérification |
| --- | --- | --- |
| 1 | Installer nvm + Node 24 | node -v → v24.x |
| 2 | Installer Claude Code (npm -g) | claude --version |
| 3 | Authentifier Claude Code | claude -p "hello" fonctionne |
| 4 | Installer GitHub CLI (gh) | gh --version |
| 5 | Authentifier gh (auth login ou token) | gh auth status |
| 6 | Installer OpenClaw | openclaw --version |
| 7 | Configurer Haiku 4.5 dans OpenClaw | openclaw doctor |
| 8 | Créer le bot Telegram (@BotFather) | Token copié |
| 9 | Configurer canal Telegram dans OpenClaw | openclaw channels status |
| 10 | Pairing Telegram | Le bot répond |
| 11 | Ajouter route openclaw dans Cloudflare Tunnel | Public hostname créé |
| 12 | Créer la policy Cloudflare Access | Auth email fonctionne |
| 13 | Configurer gateway token + approuver device | WebChat répond |
| 14 | Créer le workspace (projects/, skills/, scripts/) | ls ~/openclaw/workspace |
| 15 | Cloner les repos dans projects/ | git status dans chaque |
| 16 | Créer les 6 skills (SKILL.md) | Dossiers présents |
| 17 | Créer et chmod les scripts | Scripts exécutables |
| 18 | Ajouter VIBE.md dans chaque projet | Fichiers présents |
| 19 | Créer les labels GitHub sur chaque repo | gh label list |
| 20 | Configurer le cron morning-report | /cron list via Telegram |
| 21 | Tester : review + issues créées automatiquement | Issues visibles sur GitHub |
| 22 | Tester : merge + deploy complet | Cycle complet OK |

> **Attention** : Rappels : 1) Le port 18789 est protégé par Cloudflare Access + gateway token (double auth). 2) Plafond API sur console.anthropic.com. 3) Claude Code -p refuse d'écrire si branche = main. 4) Sauvegarder ~/.openclaw/ et ~/.claude/ sur le NAS. 5) Créer les labels GitHub sur chaque repo.

> **Resultat** : 🦞⚡
 **Architecture hybride :** WebChat (bureau) ou Telegram (mobile) → OpenClaw (Haiku) → Skill → claude -p (Max) → Travail dans le codebase → Issues GitHub → Résultat
