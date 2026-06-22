---
date: 2026-04-11
tags: [homelab, deployment, plan]
status: ready-to-execute
---

# Plan de déploiement des apps sur le homelab

Déploiement de **my_portfolio**, **ladtc** et **HillsRun** sur le homelab UM880 (Coolify + Cloudflare Tunnel). Objectif : friction minimale, pas de downtime, rollback rapide à chaque étape.

## 1. État actuel — snapshot vérifié

### Infrastructure homelab
- **Coolify** : 4.0.0-beta.472, sain, 15 containers actifs (Coolify core, Nextcloud AIO, Uptime Kuma)
- **Cloudflared** : systemd avec token embarqué (pas de `config.yml`, géré via Dashboard Cloudflare Zero Trust)
- **Postgres** : aucun Postgres standalone installé à ce jour
- **Disque** : 30 Go / 937 Go utilisés (4 %), RAM 29 Go dont 3.7 Go en usage, load 0.12
- **Réseau** : UFW ouvre 22, 8000, 8080, 11000 ; 3493 réservé au NAS
- **Sauvegarde** : `b2-backup.sh` corrigé et exécuté (65 MiB sync Nextcloud/appdata/backups → `b2:homelab-backup-anthemion`). Cron prévu à 04:00

### Projet my_portfolio
- **Stack** : Next.js 16, `output: "export"` (full static)
- **Hosting réel** : **Cloudflare Pages** (`wrangler.jsonc` présent ; README mentionnant Vercel obsolète)
- **DNS** : Cloudflare (`kenia.ns.cloudflare.com`, `sid.ns.cloudflare.com`)
- **Git** : 11 fichiers non commités à trier avant toute migration
- **Particularité** : pas de backend, pas de DB, aucune donnée à migrer

### Projet ladtc
- **Stack** : Next.js 16 (App Router, `output: "standalone"`), Prisma, PostgreSQL
- **Migration déjà préparée dans le repo** : commit `bef3d7b` "migrate from Vercel to Coolify self-hosted deployment"
- **Assets prêts** : `Dockerfile` multi-stage (node:20-alpine), `docker-compose.coolify.yml` (db `postgres:15-alpine` + app + healthcheck `/api/health`)
- **Services tiers** :
  - Stripe webhook `/api/stripe/webhook` (mode live)
  - Resend `noreply@ladtc.be`
  - 8 migrations Prisma
- **Hosting actuel** : Vercel (76.76.21.21), DNS OVH (`ns16.ovh.net`, `dns16.ovh.net`)
- **Particularité** : domaine `.be`, DNS hors Cloudflare → coupure DNS à orchestrer

### Projet data-mastery
- **Stack** : Astro 6 + `@astrojs/cloudflare`, BetterAuth, Stripe, Content Collections (38 `.md`)
- **Runtime actuel** : Cloudflare Workers (`wrangler deploy`)
- **Base de données** : Cloudflare D1 (SQLite serverless, 6 tables : 4 BetterAuth + `entitlement` + `invite_code`)
- **Secrets Cloudflare** : `BETTER_AUTH_SECRET`, `STRIPE_SECRET_KEY`, `STRIPE_WEBHOOK_SECRET` (live)
- **Produits Stripe live** : `price_1TEbJfKCLMmXXobcnj8WKnm4` (97 € Level 1), `price_1TEbK2KCLMmXXobcMhY4pO2e` (197 € Accès complet)
- **Domaine** : `datamastery.dev` (Cloudflare, zone déjà gérée)
- **Content sync** : Obsidian → `sync-from-obsidian.sh` → `wrangler deploy`
- **Particularité** : 9 fichiers importent `env` depuis `'cloudflare:workers'` → adaptation nécessaire ; `engines.node >= 22.12.0` dans `package.json`

### Projet HillsRun
- **Stack** :
  - Backend FastAPI (Python 3.11-slim), `Dockerfile.api` port 8000, asyncpg
  - Frontend Next.js (Vercel actuellement)
- **Base de données** : Neon PostgreSQL (`ep-fragrant-mouse-ag84s9ho-pooler.c-2.eu-central-1.aws.neon.tech`)
- **Replica** : logical replication Neon → Postgres sur NAS déjà existante
- **Secrets critiques** : Garmin tokens chiffrés Fernet dans `~/.garminconnect` côté API — **à préserver absolument**
- **URLs déclarées** : `app.hillsrun.com`, `api.hillsrun.com`
- **Git** : état propre
- **Particularité** : seul projet avec backend stateful + logique d'ingestion externe (Garmin) → migration hybride recommandée

### SecondBrain
- Dossier `01-Projects/homelab/` : 6 guides (manuel, troubleshooting, maintenance, guide final, guide post-audit, openclaw hybride)
- Pas de `Roadmap Projets.md` ni pattern documenté pour le déploiement d'apps tierces sur l'UM880

## 2. Décisions validées (reco assumée)

| # | Point | Décision | Raison |
|---|-------|----------|--------|
| D1 | Portfolio hosting cible | **Rester sur Cloudflare Pages** en prod ; déployer une copie de staging sur Coolify | Static = zéro bénéfice à self-host ; staging sert de banc d'essai Coolify low-risk |
| D2 | Postgres homelab | **Postgres 16 mutualisé** (un seul service Coolify + DB/schéma par app) | Moins de conteneurs, sauvegarde unique, ladtc + HillsRun peuvent cohabiter |
| D3 | HillsRun migration | **Hybride** : API FastAPI sur homelab, frontend Next.js sur Vercel, DB Neon conservée en lecture, replica NAS promue en write si besoin | Garmin tokens + logical replication déjà en place → on évite de déplacer ces bords sensibles |
| D4 | Gestion secrets | **Coolify UI** (variables d'environnement par app), Stripe/Resend injectés via UI, pas de Vault externe | Coolify chiffre déjà ses env vars ; pas d'overhead |
| D5 | UM790 (ancienne doc) | **Considérer comme artefact** de documentation obsolète, purger des guides actifs | Évite confusion lecteur futur |
| D6 | DNS ladtc | **OVH → Cloudflare** avant cutover Coolify | Permet rollback rapide via proxy Cloudflare + TLS auto + health routing |
| D7 | data-mastery runtime | **Migration complète Cloudflare Workers → homelab** (swap `@astrojs/cloudflare` → `@astrojs/node` standalone) | Mutualise Postgres + secrets + monitoring ; supprime la dépendance Workers/D1 ; cohérence avec ladtc |
| D8 | data-mastery DB | **D1 → Postgres mutualisé** (schéma `datamastery` sur le Postgres de Phase A) | Une seule sauvegarde `pg_dumpall`, un seul backend à superviser |

## 3. Phases d'exécution

Ordre : **A → B → C → D**. Chaque phase est validable indépendamment et réversible.

### Phase A — Prérequis homelab (socle commun)

Objectif : rendre le homelab capable d'accueillir des apps avec DB, secrets et exposition Tunnel.

- [ ] **A1** Déployer Postgres 16 mutualisé sur Coolify
  - Service Coolify type `Database → PostgreSQL 16`
  - Volume persistant `coolify_postgres_data`
  - User admin + mot de passe stockés dans Coolify secrets
  - Exposer uniquement en interne (réseau Coolify), pas d'UFW
- [ ] **A2** Ajouter Postgres à la routine de sauvegarde B2
  - Modifier `/usr/local/bin/b2-backup.sh` : ajouter `pg_dumpall` → `/mnt/nas/backups/pg/` avant le `rclone sync`
  - Test manuel → log vérifié → planifier dans cron existant
- [ ] **A3** Configurer hostnames Cloudflare Tunnel via Dashboard Zero Trust
  - `staging-portfolio.anthemion.dev` → `http://coolify:80` (placeholder)
  - `ladtc.be` + `www.ladtc.be` → `http://coolify:80`
  - `api.hillsrun.com` → `http://coolify:8000`
  - Note : cloudflared est géré par token embarqué — **pas** de `config.yml` à toucher
- [ ] **A4** Ajouter monitoring Uptime Kuma pour les 3 URLs cibles (keyword check + heartbeat 60 s)
- [ ] **A5** Créer template skill `openclaw deploy-check` (lecture seule : `coolify status`, `docker ps`, healthchecks des 3 apps) — optionnel mais recommandé pour la routine

**Validation phase A** : Postgres visible dans Coolify, `pg_dump` présent dans la dernière run B2, un hostname test Cloudflare répond 200 via tunnel.

### Phase B — Portfolio en staging (pilote low-risk)

Objectif : valider la chaîne Coolify → Tunnel → TLS sur une app sans état.

- [ ] **B1** Trier les 11 changements non commités dans `~/Projects/my_portfolio/` : commit ou stash propre avant toute manip
- [ ] **B2** Créer `Dockerfile.staging` minimal (nginx alpine servant le `out/` statique) **OU** utiliser `serve` via `output: "standalone"` bypass — choisir au moment du build
- [ ] **B3** Créer app Coolify `portfolio-staging` depuis le repo GitHub (branche `staging` à créer)
- [ ] **B4** Déployer, vérifier `staging-portfolio.anthemion.dev` → 200 OK
- [ ] **B5** Ajouter au dashboard Uptime Kuma
- [ ] **B6** Aucun changement prod : Cloudflare Pages reste live sur le domaine principal

**Validation phase B** : staging atteint publiquement, rollback = désactiver l'app Coolify.

### Phase C — ladtc (Vercel → Coolify)

Objectif : migrer une app stateful en production avec cutover DNS contrôlé.

- [ ] **C1** Export complet DB Vercel/Postgres source (si existant) ou dump local → fichier SQL
- [ ] **C2** Créer schéma `ladtc` dans le Postgres homelab, importer le dump, lancer `prisma migrate deploy`
- [ ] **C3** Créer app Coolify `ladtc` depuis le repo (branche `main`, `docker-compose.coolify.yml`)
- [ ] **C4** Injecter les variables d'env dans Coolify UI :
  - `DATABASE_URL` → Postgres homelab
  - `STRIPE_SECRET_KEY`, `STRIPE_WEBHOOK_SECRET` (live)
  - `RESEND_API_KEY`, `RESEND_FROM=noreply@ladtc.be`
  - BetterAuth secret
- [ ] **C5** Déploiement sur hostname temporaire `staging-ladtc.anthemion.dev`, healthcheck `/api/health`
- [ ] **C6** Test Stripe webhook : ajouter l'endpoint staging dans le Dashboard Stripe, déclencher un événement test, vérifier traitement
- [ ] **C7** Test Resend : envoi email transactionnel de bout en bout
- [ ] **C8** **Transférer DNS `ladtc.be` OVH → Cloudflare** (ajouter le domaine dans Cloudflare, importer la zone, changer les nameservers chez OVH)
  - Attendre propagation (TTL 1 h à 24 h selon OVH)
- [ ] **C9** Créer enregistrements Cloudflare : `ladtc.be` et `www.ladtc.be` → CNAME tunnel (proxied orange)
- [ ] **C10** Mettre à jour endpoint Stripe webhook sur `https://ladtc.be/api/stripe/webhook`
- [ ] **C11** Surveillance 24 h (Uptime Kuma + logs Coolify + Dashboard Stripe)
- [ ] **C12** Une fois stable : supprimer le projet Vercel, retirer l'ancien webhook Stripe

**Validation phase C** : `ladtc.be` répond depuis homelab, checkout Stripe fonctionnel, email Resend reçu.
**Rollback** : si échec, repointer DNS `ladtc.be` vers Vercel (CNAME alias) — reste < 5 min après suppression du tunnel record.

### Phase D — HillsRun (hybride API seule)

Objectif : déplacer uniquement l'API FastAPI sur homelab, garder Vercel pour le front et Neon en source de vérité.

- [ ] **D1** Créer schéma `hillsrun_mirror` dans Postgres homelab (à usage monitoring/backup, pas pour lecture API)
- [ ] **D2** Valider que la logical replication Neon → NAS est toujours active (elle l'est au jour du plan) — c'est le fallback read
- [ ] **D3** Créer app Coolify `hillsrun-api` depuis le repo (Dockerfile.api, port 8000)
- [ ] **D4** Injecter env vars Coolify :
  - `DATABASE_URL` → Neon (inchangé — on ne casse pas ce qui marche)
  - `GARMIN_FERNET_KEY` (depuis `~/.garminconnect` actuel — **backup avant toute manip**)
  - Tous les secrets listés dans `~/Projects/HillsRun/api/.env` actuel
- [ ] **D5** Persister `~/.garminconnect` dans un volume Coolify dédié (bind mount vers `/mnt/nas/appdata/hillsrun/garminconnect/`)
- [ ] **D6** Déployer sur `staging-api.hillsrun.com`, tester `/healthz` et un endpoint Garmin read
- [ ] **D7** Switch DNS `api.hillsrun.com` (Cloudflare déjà en place) : `CNAME api → tunnel` avec proxy activé
- [ ] **D8** Mettre à jour `NEXT_PUBLIC_API_URL` sur Vercel front → redéployer
- [ ] **D9** Surveillance 48 h (Garmin ingestion + latence Neon + logs Coolify)
- [ ] **D10** Après stabilité : déprécier Railway (supprimer déploiement, garder repo `Dockerfile.api`)

**Validation phase D** : front Vercel charge via `api.hillsrun.com` homelab, ingestion Garmin continue, aucun token perdu.
**Rollback** : réactiver Railway ou repointer DNS `api.hillsrun.com` sur l'ancien Railway. Neon inchangé = zero data loss.

### Phase E — data-mastery (Cloudflare Workers → homelab)

Objectif : sortir de Cloudflare Workers + D1, basculer l'app Astro sur le runtime Node mutualisé du homelab, tout en conservant le domaine `datamastery.dev` sur Cloudflare (proxy + tunnel).

Chantier plus large que C : il touche au runtime (adapter), à la DB (dialect SQL), et aux imports `cloudflare:workers` présents dans 9 fichiers. À traiter sur une journée dédiée.

- [ ] **E1** Inventaire gelé avant travaux
  - `git status` propre dans `~/Projects/data-mastery-platform/`
  - Export schéma D1 : `wrangler d1 export <db-name> --output=d1-schema.sql`
  - Export données D1 : `wrangler d1 execute <db-name> --remote --command=".dump"` (ou export table par table via `SELECT * FROM ...`)
  - Sauvegarder les 3 secrets actuels (lecture seule, ne pas les copier dans le repo)
- [ ] **E2** Créer le schéma `datamastery` dans le Postgres mutualisé (Phase A)
  - `CREATE SCHEMA datamastery; CREATE USER datamastery WITH PASSWORD '...';`
  - Grant sur schéma uniquement (pas de superuser)
- [ ] **E3** Traduire le schéma SQL D1 (SQLite) → Postgres
  - `INTEGER PRIMARY KEY AUTOINCREMENT` → `BIGSERIAL PRIMARY KEY`
  - `TEXT` inchangé, `INTEGER` pour booléens → `BOOLEAN`
  - `DATETIME DEFAULT CURRENT_TIMESTAMP` → `TIMESTAMPTZ DEFAULT NOW()`
  - Contraintes `UNIQUE` / `NOT NULL` à reporter à l'identique
  - Vérifier les 6 tables : `user`, `session`, `account`, `verification` (BetterAuth) + `entitlement` + `invite_code`
- [ ] **E4** Importer les données D1 → Postgres (dump réécrit)
  - Script de migration : parser le `.dump` SQLite, réinjecter via `psql`
  - Vérifier les counts ligne à ligne après import
- [ ] **E5** Dans le repo data-mastery, swap de l'adapter
  - `pnpm remove @astrojs/cloudflare kysely-d1`
  - `pnpm add @astrojs/node pg kysely`
  - `astro.config.mjs` : `import node from '@astrojs/node'` + `adapter: node({ mode: 'standalone' })`
  - `output: 'server'` conservé
- [ ] **E6** Adapter la couche DB (Kysely)
  - `kysely-d1` → `PostgresDialect` de `kysely` avec `pg.Pool`
  - `db.ts` : lire `DATABASE_URL` depuis `process.env` au lieu de `env.DB` (`cloudflare:workers`)
  - Traduire les requêtes dialect-specific :
    - `INSERT OR IGNORE` → `ON CONFLICT DO NOTHING`
    - `randomblob(16)` / `hex(randomblob(16))` → `gen_random_uuid()` (extension `pgcrypto` à activer)
    - `strftime(...)` → `to_char(...)` si présent
- [ ] **E7** Adapter les 9 fichiers qui importent `env` depuis `'cloudflare:workers'`
  - Remplacer par `process.env.XXX` (lecture Node)
  - Supprimer les accès `locals.runtime.env` côté Astro (plus de runtime Workers)
  - Vérifier chaque route `src/pages/api/*` et le middleware
- [ ] **E8** Vérifier le moteur Node
  - `package.json` déclare `engines.node >= 22.12.0`
  - Base `node:20-alpine` (Dockerfile standard homelab) : **KO** → passer sur `node:22-alpine`
  - Test local `pnpm build` sur Node 22
- [ ] **E9** Écrire `Dockerfile` multi-stage (calqué sur ladtc, base `node:22-alpine`)
  - Stage deps (`pnpm install --frozen-lockfile`)
  - Stage builder (`pnpm build`) → produit `dist/server/entry.mjs`
  - Stage runner (copier `dist/`, `package.json`, `node_modules/` en prod)
  - Port 4321 (Astro standalone) ou 3000 selon config adapter
  - HEALTHCHECK `wget -qO- http://127.0.0.1:4321/api/health || exit 1` (créer l'endpoint si absent)
- [ ] **E10** Secrets homelab dans `~/.secrets/`
  - `datamastery-db.pass`, `datamastery-betterauth.secret`, `datamastery-stripe-secret.key`, `datamastery-stripe-webhook.key`
  - Injection via `IFS= read -rs V && printf "%s" "$V" > ~/.secrets/datamastery-xxx && chmod 600`
  - **Les secrets Cloudflare Workers live sont conservés tant que Workers tourne** (pas de rotation pendant la bascule)
- [ ] **E11** Premier déploiement sur `staging-datamastery.anthemion.dev`
  - Créer le hostname dans Cloudflare Tunnel (Dashboard Zero Trust)
  - `docker run -d --name datamastery-staging` avec labels Traefik + healthcheck + env
  - `db:ok` via endpoint santé
- [ ] **E12** Valider fonctionnellement en staging
  - Accueil, landing, Content Collections (38 articles)
  - Login BetterAuth (session Postgres)
  - Invite code → check contrainte unique
  - Entitlement check sur une page protégée
  - Stripe Workbench : `stripe trigger checkout.session.completed` sur l'URL staging → vérifier entitlement créé
- [ ] **E13** Cutover DNS `datamastery.dev`
  - La zone est déjà sur Cloudflare → pas de changement NS
  - Modifier les records A/CNAME : `datamastery.dev` + `www` → CNAME tunnel (proxied orange)
  - Baisser le TTL à 300 s quelques heures avant la bascule
  - Temps de bascule : quasi instantané (Cloudflare propage en < 1 min)
- [ ] **E14** Mettre à jour le webhook Stripe **live mode**
  - Dashboard Stripe → Webhooks → endpoint existant → URL `https://datamastery.dev/api/stripe/webhook`
  - Récupérer le nouveau `whsec_...` si rotation
  - Vérifier signature sur un événement live suivant (ou via Workbench)
- [ ] **E15** Surveillance 24 h (Uptime Kuma + logs Coolify + Dashboard Stripe + BetterAuth sessions)
- [ ] **E16** Décommissionner Cloudflare Workers
  - `wrangler delete` de l'app Workers
  - Supprimer la DB D1 (après vérif de l'import Postgres)
  - Retirer les secrets Cloudflare
  - Adapter `sync-from-obsidian.sh` : `wrangler deploy` → `git push` (le contenu md est dans le repo, Coolify redéploie)

**Validation phase E** : `datamastery.dev` répond depuis homelab, checkout Stripe live fonctionnel, login BetterAuth OK, 38 articles accessibles.
**Rollback** : repointer DNS sur l'ancienne URL Workers (Cloudflare record orange cloud désactivé pour bypass tunnel) — reste réversible tant que Workers n'est pas supprimé (E16 est la dernière étape, irréversible).

## 4. Risques identifiés et mitigations

| Risque | Phase | Mitigation |
|--------|-------|------------|
| DNS cutover OVH → Cloudflare long (jusqu'à 24 h) | C8 | Démarrer tôt le matin, laisser Vercel actif en parallèle tant que propagation incomplète |
| Stripe webhook perdu pendant bascule | C10 | Configurer les deux endpoints (Vercel + homelab) en parallèle quelques heures, puis couper Vercel |
| Garmin tokens Fernet corrompus | D5 | `tar czf garminconnect-backup.tgz ~/.garminconnect` avant bind mount |
| Neon coupe l'accès depuis nouvelle IP sortante | D6 | Vérifier IP allowlist Neon Dashboard avant D6 |
| Cloudflared config perdue si reboot avant save | A3 | Le token est dans systemd unit — vérifier `systemctl cat cloudflared` avant de toucher quoi que ce soit |
| Coolify UI accessible publiquement par mégarde | toutes | Vérifier UFW : 8000/8080 en localhost uniquement ou protégé par Cloudflare Access |
| Traduction SQLite → Postgres incomplète (contraintes, types) | E3-E4 | Comparer les counts ligne à ligne table par table après import ; tester en staging avant DNS cutover |
| Import `'cloudflare:workers'` oublié dans un fichier | E7 | `grep -r "from 'cloudflare:workers'" src/` avant build ; build échoue sinon sous Node pur |
| Node engine `>= 22.12.0` incompatible avec image par défaut | E8 | Base `node:22-alpine` explicitement dans le Dockerfile data-mastery |
| Perte de la capacité `wrangler deploy` pour sync Obsidian | E16 | Adapter `sync-from-obsidian.sh` → git push + Coolify webhook avant suppression Workers |
| Webhook Stripe live cassé pendant cutover | E14 | Conserver l'ancien endpoint Workers actif + nouveau endpoint homelab en parallèle 24 h, puis couper |

## 5. Ordre d'exécution

```
A1 → A2 → A3 → A4         (socle)
  ↓
B1 → B6                   (pilote low-risk)
  ↓
C1 → C12                  (prod critique ladtc avec cutover DNS)
  ↓
D1 → D10                  (hybride HillsRun API)
  ↓
E1 → E16                  (migration runtime data-mastery, chantier d'une journée dédiée)
```

Chaque phase doit être validée avant d'attaquer la suivante. Pas de parallélisation tant que le socle A n'est pas vert. Phase E est la plus lourde — ne pas l'enchaîner directement après C ou D sans pause.

## 6. Post-déploiement

- Mettre à jour `homelab-manuel.md` avec les 4 apps (my_portfolio staging, ladtc, hillsrun-api, data-mastery) et leurs endpoints
- Créer `homelab-apps-runbook.md` (restart, redeploy, rollback par app)
- Skill OpenClaw `apps-status` : check healthcheck des 4 apps + Postgres + tunnel (à intégrer dans la routine matin)
- Mise à jour Roadmap personnelle SecondBrain : retrait Vercel (portfolio reste Cloudflare Pages), retrait Cloudflare Workers (data-mastery passe au homelab), ladtc + hillsrun-api + data-mastery tous sur homelab

---

**Sources consultées pour ce plan** :
- `~/Projects/HillsRun/` (Dockerfile.api, docker-compose, .env.example, README)
- `~/Projects/ladtc/` (docker-compose.coolify.yml, Dockerfile, prisma/, .env.example, git log)
- `~/Projects/my_portfolio/` (wrangler.jsonc, next.config, git status)
- `~/Projects/data-mastery-platform/` (CLAUDE.md, astro.config, wrangler config, schémas D1, imports `cloudflare:workers`)
- `~/Documents/SecondBrain/01-Projects/homelab/` (6 guides existants)
- Homelab live state : `ssh homelab` (coolify status, docker ps, systemctl, df, free)
- État externe : DNS publics (OVH, Cloudflare), providers actuels (Vercel, Cloudflare Workers, Neon, D1)
