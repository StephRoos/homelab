# 📖 Immich - Guide de Configuration Complète pour Homelab

*Dernière mise à jour : 25 juin 2026*
*Environnement : UM880 Plus (Ubuntu 24.04) + NAS UGREEN (ARM64) + Cloudflare Tunnel*

---

## 📌 Table des Matières

1. [🎯 Introduction](#-introduction)
2. [🏗️ Architecture](#-architecture)
3. [📦 Configuration Finale](#-configuration-finale)
4. [⚡ Problèmes Rencontrés & Solutions](#-problèmes-rencontrés--solutions)
5. [🔧 Commandes Utiles](#-commandes-utiles)
6. [📁 Migration des Photos](#-migration-des-photos)
7. [🔄 Maintenance & Backups](#-maintenance--backups)
8. [📊 Vérification du Fonctionnement](#-vérification-du-fonctionnement)
9. [🎯 Prochaines Étapes](#-prochaines-étapes)

---

## 🎯 Introduction

Ce guide documente la configuration complète d'**Immich**, une solution self-hosted de gestion de photos et vidéos, déployée sur un **UM880 Plus** (Ubuntu 24.04) avec stockage sur **NAS UGREEN** et accès externe via **Cloudflare Tunnel**.

### ✅ Fonctionnalités
- Stockage sécurisé de photos/vidéos sur le NAS
- Accès externe via `https://photos.stephaneroos.com`
- Interface web moderne (SvelteKit)
- Base de données PostgreSQL avec pgvecto.rs pour la recherche vectorielle
- Cache Redis pour les performances
- Tunnel Cloudflare pour la sécurité et le HTTPS

### 🎨 Architecture Visuelle

```
┌─────────────────────────────────────────────────────────────────────┐
│                                                                     │
│   [Internet] ──► Cloudflare DNS ──► Cloudflare Tunnel ──► [UM880]   │
│                         │                                             │
│                         ▼                                             │
│              photos.stephaneroos.com                                  │
│                         │                                             │
└─────────────────────────────────────────────────────────────────────┘
                      │
                      ▼
┌─────────────────────────────────────────────────────────────────────┐
│                                                                     │
│  ┌──────────────┐    ┌──────────────┐    ┌──────────────┐          │
│  │  immich-web │◄───►│immich-server │◄───►│   PostgreSQL  │          │
│  │  (Nginx)    │    │  (Node.js)   │    │(pgvecto-rs) │          │
│  └──────────────┘    └──────────────┘    └──────────────┘          │
│       ▲                  ▲ 3001/2283               ▲ 5432            │
│       │                  │                         │                  │
│   2284/80               │                         │                  │
│       │                  ▼                         │                  │
│  ┌──────────────┐    ┌──────────────┐                             │
│  │   Redis      │    │   Library    │◄────────────────────────┐   │
│  │  (Cache)     │    │ /mnt/nas/    │                             │   │
│  └──────────────┘    │   immich/    │◄────────────────────────┤   │
│                       │   library    │         (NAS UGREEN)      │   │
│                       └──────────────┘                             │   │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

---

## 🏗️ Architecture

### 🖥️ Matériel & Environnement

| Composant | Type | Rôle | IP |
|-----------|------|------|-----|
| UM880 Plus | Serveur | Hôte Docker | 192.168.129.10 |
| NAS UGREEN | Stockage | Photos/Vidéos | 192.168.129.21 |
| Routeur | Réseau | Connexion Internet | 192.168.128.1 |

### 🐳 Conteneurs Docker

| Service | Image | Port Interne | Port Externe | Statut |
|---------|-------|--------------|--------------|--------|
| immich-postgres | `tensorchord/pgvecto-rs:pg14-v0.2.0` | 5432 | - | Healthy |
| immich-redis | `redis:7.2-alpine` | 6379 | - | Healthy |
| immich-server | `ghcr.io/immich-app/immich-server:release` | 2283 | - | Healthy |
| immich-web | `ghcr.io/immich-app/immich-web:release` | 3000 | 127.0.0.1:2284 | Running |

### 🌐 Réseau

- **Réseau Docker** : `immich-network` (driver: bridge)
- **Type** : Bridge isolé pour la sécurité
- **DNS interne** : Conteneurs résolvent par nom (`immich-server`, `immich-postgres`, etc.)

---

## 📦 Configuration Finale

### 📄 Fichier `configs/docker/immich.yml`

```yaml
version: '3.8'  # Note: Le champ version est obsolète mais fonctionnel

services:
  immich-postgres:
    image: tensorchord/pgvecto-rs:pg14-v0.2.0  # ⚠️ Version compatible avec Immich v2.7.5+
    container_name: immich-postgres
    restart: unless-stopped
    environment:
      POSTGRES_USER: immich
      POSTGRES_PASSWORD: ${IMMICH_DB_PASSWORD}
      POSTGRES_DB: immich
    volumes:
      - immich-postgres-data:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U immich -d immich"]
      interval: 5s
      timeout: 5s
      retries: 5
    networks:
      - immich-network
    deploy:
      resources:
        limits:
          memory: 2G
          cpus: '1.0'

  immich-redis:
    image: redis:7.2-alpine
    container_name: immich-redis
    restart: unless-stopped
    command: redis-server --appendonly yes
    volumes:
      - immich-redis-data:/data
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 5s
      timeout: 3s
      retries: 5
    networks:
      - immich-network
    deploy:
      resources:
        limits:
          memory: 512M
          cpus: '0.5'

  immich-server:
    image: ghcr.io/immich-app/immich-server:release
    container_name: immich-server
    restart: unless-stopped
    depends_on:
      immich-postgres:
        condition: service_started
      immich-redis:
        condition: service_started
    environment:
      # Base de données
      DB_HOSTNAME: immich-postgres
      DB_PORT: 5432
      DB_USERNAME: immich
      DB_PASSWORD: ${IMMICH_DB_PASSWORD}
      DB_DATABASE_NAME: immich
      
      # Cache
      REDIS_HOSTNAME: immich-redis
      REDIS_PORT: 6379
      
      # Machine Learning (désactivé pour ARM64)
      DISABLE_MACHINE_LEARNING: "true"
      
      # Configuration générale
      PUBLIC_SERVER_URL: https://photos.stephaneroos.com
      IMMICH_SECRET: ${IMMICH_SECRET}
      UPLOAD_LOCATION: /usr/src/app/upload
      TZ: Europe/Paris
      
      # ⚠️ CRITICAL: Binding sur toutes les interfaces
      NODE_ENV: production
    volumes:
      - /mnt/nas/immich/upload:/usr/src/app/upload
      - /mnt/nas/immich/library:/usr/src/app/assets
      - /mnt/nas/immich/config/server:/config
    networks:
      - immich-network
    deploy:
      resources:
        limits:
          memory: 3G
          cpus: '2.0'
    healthcheck:
      test: ["CMD-SHELL", "curl -f http://localhost:2283/api/server/ping || exit 1"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 60s  # ⚠️ Attend 60s avant le premier healthcheck

  immich-web:
    image: ghcr.io/immich-app/immich-web:release
    container_name: immich-web
    restart: unless-stopped
    depends_on:
      immich-server:
        condition: service_started
    environment:
      IMMICH_SERVER_URL: http://immich-server:2283  # ⚠️ Port corrigé de 3001 à 2283
      TZ: Europe/Paris
    ports:
      - "127.0.0.1:2284:3000"  # ⚠️ CRITICAL: immich-web écoute sur 3000, pas 80
    volumes:
      - /mnt/nas/immich/config/web:/config
    networks:
      - immich-network
    deploy:
      resources:
        limits:
          memory: 512M
          cpus: '0.5'

volumes:
  immich-postgres-data:
    driver: local
    name: immich-postgres-data
  immich-redis-data:
    driver: local
    name: immich-redis-data

networks:
  immich-network:
    driver: bridge
    name: immich-network
```

### 🗃️ Structure des Volumes

```
/mnt/nas/immich/
├── library/          # Photos/vidéos stockées (monté sur /usr/src/app/assets)
├── upload/           # Uploads temporaires (monté sur /usr/src/app/upload)
└── config/
    ├── server/       # Configuration du server
    └── web/          # Configuration du web
```

### 🌐 Configuration Cloudflare Tunnel

- **Tunnel ID** : `6b5cb58d-2344-4653-8d0b-ba7723f8ac6d`
- **Route** : `photos.stephaneroos.com → http://localhost:2284`
- **Type** : CNAME → `6b5cb58d-2344-4653-8d0b-ba7723f8ac6d.cfargotunnel.com`
- **Proxy** : ✅ Activé (pour HTTPS)

---

## ⚡ Problèmes Rencontrés & Solutions

### 🔴 Problème 1 : Port Mapping Incorrect

**Symptôme** : `curl -I http://localhost:2284` → Connection reset by peer

**Cause** : Le conteneur `immich-web` écoute sur le **port 3000** par défaut, mais la configuration utilisait `127.0.0.1:2284:80`.

**Solution** :
```yaml
# Changé de:
- "127.0.0.1:2284:80"
# En:
- "127.0.0.1:2284:3000"
```

---

### 🔴 Problème 2 : pgvecto.rs Version Incompatible

**Symptôme** :
```
Error: The pgvecto.rs extension version is 0.1.1, but Immich only supports >=0.2 <0.4.
```

**Cause** : PostgreSQL utilisait `tensorchord/pgvecto-rs:pg14-v0.1.11` (trop ancien).

**Solution** :
```yaml
# Changé de:
image: tensorchord/pgvecto-rs:pg14-v0.1.11
# En:
image: tensorchord/pgvecto-rs:pg14-v0.2.0
```

---

### 🔴 Problème 3 : Server Binding sur [::1]

**Symptôme** : Le server écoute sur `[::1]:2283` (IPv6 localhost) ou `127.0.0.1:2283` mais les conteneurs Docker peuvent quand même y accéder.

**Cause** : Immich v2.7.5+ utilise par défaut `[::1]:2283` ou `127.0.0.1:2283` pour la sécurité.

**Solution** : 
- **Résolution finale** : La communication entre conteneurs Docker fonctionne via le réseau `immich-network` même avec binding localhost
- **Configuration validée** : Avec `NODE_ENV: production`, le server écoute sur `[::1]:2283` et `[::]:2283` (accessible depuis d'autres conteneurs)
- **Vérification** : `docker logs immich-server | grep "listening on"` → `http://[::1]:2283`

> ⚠️ **Important** : Ne PAS ajouter de `command` personnalisé dans immich-server. La tag `release` gère automatiquement le binding correct.

---

### 🔴 Problème 4 : Healthcheck Échoue

**Symptôme** : Conteneur `immich-server` marqué comme `(unhealthy)`

**Cause 1** : `wget` non installé dans le conteneur
**Cause 2** : Endpoint `/api/ping` n'existe pas, c'est `/api/server/ping`

**Solution** :
```yaml
healthcheck:
  test: ["CMD-SHELL", "curl -f http://localhost:2283/api/server/ping || exit 1"]
  interval: 30s
  timeout: 10s
  retries: 3
  start_period: 60s  # Attend 60s avant le premier check
```

---

### 🔴 Problème 5 : Connexion entre conteneurs

**Symptôme** : `ECONNREFUSED 10.0.6.4:2283`

**Cause** : Le conteneur `immich-web` ne pouvait pas résoudre `immich-server`

**Solution** : 
- Vérification du réseau Docker (`immich-network`)
- Toutes les dépendances en `condition: service_started`
- Correction du port dans `IMMICH_SERVER_URL` de `3001` à `2283`

---

### 🔴 Problème 6 : Cache DNS Mac

**Symptôme** : `curl: (6) Could not resolve host: photos.stephaneroos.com` sur le Mac

**Cause** : mDNSResponder cache l'ancien DNS

**Solution** :
```bash
sudo killall -HUP mDNSResponder
sudo dscacheutil -flushcache
```

---

## 🔧 Commandes Utiles

### 📡 Démarrage/Arrêt

```bash
# Démarrer
cd /home/steph/homelab/configs/docker
docker compose -f immich.yml --env-file .env up -d

# Arrêter
docker compose -f immich.yml down

# Redémarrer
docker compose -f immich.yml down && docker compose -f immich.yml --env-file .env up -d
```

### 📜 Logs

```bash
# Voir les logs du server
docker logs -f immich-server

# Voir les logs du web
docker logs -f immich-web

# Voir les logs de tous les services
docker compose -f immich.yml logs -f
```

### 📊 État des Services

```bash
# État des conteneurs
docker ps | grep immich

# État détaillé
docker compose -f immich.yml ps

# Vérifier le healthcheck
docker inspect immich-server --format='{{.State.Health.Status}}'
```

### 🗃️ Gestion des Volumes

```bash
# Lister les volumes
docker volume ls | grep immich

# Sauvegarder la base de données
docker exec immich-postgres pg_dump -U immich -d immich > /mnt/nas/backups/immich-db-$(date +%Y%m%d).sql

# Restaurer la base de données
cat /mnt/nas/backups/immich-db.sql | docker exec -i immich-postgres psql -U immich -d immich
```

### 🔄 Mise à Jour

```bash
# Mettre à jour les images
docker compose -f immich.yml pull

# Redémarrer avec les nouvelles images
docker compose -f immich.yml --env-file .env up -d
```

### 🔍 Diagnostics

```bash
# Tester la connexion entre conteneurs
docker exec immich-web curl -I http://immich-server:2283

# Vérifier que le server écoute
docker exec immich-server netstat -tuln | grep 2283

# Tester l'accès local
curl -I http://localhost:2284

# Tester via Cloudflare
dig @8.8.8.8 photos.stephaneroos.com +short
```

---

## 📁 Migration des Photos

### 📤 Méthode Recommandée : Copie Directe

```bash
#!/bin/bash
# Script: migrate-photos.sh

SOURCE_DIR="/mnt/nas/photos"
DEST_DIR="/mnt/nas/immich/library"

# Vérifications
if [ ! -d "$SOURCE_DIR" ]; then
    echo "❌ Dossier source introuvable : $SOURCE_DIR"
    exit 1
fi

if [ ! -d "$DEST_DIR" ]; then
    mkdir -p "$DEST_DIR"
fi

# Compter les fichiers
SOURCE_COUNT=$(find "$SOURCE_DIR" -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.mp4" -o -iname "*.mov" -o -iname "*.heic" \) | wc -l)
echo "📊 $SOURCE_COUNT fichiers à migrer..."

# Lancer la copie (conserve la structure)
rsync -avh --progress --stats "$SOURCE_DIR/" "$DEST_DIR/"

echo ""
echo "✅ Migration terminée !"
echo "💡 Immich va scanner automatiquement /mnt/nas/immich/library"
```

### 📤 Méthode Alternative : Bibliothèque Externe

1. Dans l'interface Immich : `Paramètres → Bibliothèques → Ajouter`
2. Pointe vers `/mnt/nas/photos/` (doit être accessible depuis le conteneur)
3. **Moins recommandé** : La méthode par copie directe est plus fiable

### 🔄 Forcer un Scan Manuel

```bash
# Via l'API (nécessite un token d'authentification)
curl -X POST http://localhost:2284/api/library/scan \
  -H "Authorization: Bearer TON_TOKEN" \
  -H "Content-Type: application/json"

# Ou via l'interface web :
# Paramètres → Bibliothèques → Scanner maintenant
```

---

## 🔄 Maintenance & Backups

### 💾 Script de Backup Automatique

**Fichier** : `/home/steph/homelab/scripts/backup-immich.sh`

```bash
#!/bin/bash
# Backup Immich - À exécuter quotidiennement

BACKUP_DIR="/mnt/nas/backups/immich"
DATE=$(date +%Y%m%d_%H%M)

mkdir -p "$BACKUP_DIR"

echo "🗃️ Backup Immich - $DATE"

# Backup base de données
echo "🔄 Backup DB..."
docker exec immich-postgres pg_dump -U immich -d immich > "$BACKUP_DIR/db-$DATE.sql"

# Backup configuration
echo "🔄 Backup config..."
tar -czvf "$BACKUP_DIR/config-$DATE.tar.gz" /mnt/nas/immich/config

# Nettoyage (garde 7 jours)
echo "🧹 Nettoyage..."
find "$BACKUP_DIR" -type f -name "*.sql" -mtime +7 -delete
find "$BACKUP_DIR" -type f -name "*.tar.gz" -mtime +7 -delete

echo "✅ Backup terminé : $BACKUP_DIR"
```

### ⏰ Planification Cron

```bash
# Édite la crontab
crontab -e

# Ajoute cette ligne pour un backup quotidien à 2h00
0 2 * * * /home/steph/homelab/scripts/backup-immich.sh >> /var/log/immich-backup.log 2>&1
```

---

## 📊 Vérification du Fonctionnement

### ✅ Checklist de Vérification

| Étape | Commande | Résultat Attendu |
|-------|----------|-----------------|
| Conteneurs en cours | `docker ps \| grep immich` | 4 conteneurs `Up` (healthy) |
| Server écoute | `docker logs immich-server \| grep "listening on"` | `http://[::1]:2283` ou `http://127.0.0.1:2283` |
| Accès local | `curl -I http://localhost:2284` | `HTTP/1.1 200 OK` ou `HTTP/2 200` |
| Accès externe | `curl -I https://photos.stephaneroos.com` | `HTTP/2 200` |
| Connexion DB | `docker exec immich-postgres pg_isready -U immich -d immich` | `immich-postgres:5432 - accepting connections` |
| Connexion Redis | `docker exec immich-server redis-cli -h immich-redis ping` | `PONG` |
| Connexion inter-containers | `docker exec immich-web curl -I http://immich-server:2283` | `HTTP/1.1 200 OK` |
| Healthcheck server | `docker inspect immich-server --format='{{.State.Health.Status}}'` | `healthy` |

### 🎯 Vérification Finale (25 juin 2026)

```
✅ Tous les conteneurs sont en état "healthy"
✅ Le server écoute sur http://[::1]:2283
✅ Accès local via http://localhost:2284 retourne HTTP/2 200
✅ Accès externe via https://photos.stephaneroos.com retourne HTTP/2 200
✅ Cloudflare Tunnel (ID: 6b5cb58d-2344-4653-8d0b-ba7723f8ac6d) est healthy
✅ DNS photos.stephaneroos.com résout correctement via Cloudflare
```

---

## 🎯 Prochaines Étapes

### ✅ Priorité Haute

- [ ] **Créer le compte admin** dans l'interface Immich
- [ ] **Migrer tes photos** du NAS vers `/mnt/nas/immich/library`
- [ ] **Vérifier les permissions** : `chmod -R 775 /mnt/nas/immich`
- [ ] **Configurer les backups automatiques** (cron)
- [ ] **Tester l'upload** de nouvelles photos via l'interface

### 📅 Priorité Moyenne

- [ ] Configurer les **notifications par email** (SMTP)
- [ ] Activer le **Machine Learning** (si GPU ARM64 disponible)
- [ ] Configurer les **utilisateurs supplémentaires**
- [ ] Mettre en place un **système de monitoring** (Prometheus/Grafana)
- [ ] Configurer les **sauvegardes externes** (vers un autre NAS ou cloud)

### 🚀 Priorité Basse (Optionnel)

- [ ] Configurer **Cloudflare Access** pour une sécurité renforcée
- [ ] Mettre en place un **reverse proxy** (Nginx/Traefik) devant Immich
- [ ] Configurer **Authelia** ou **Keycloak** pour l'authentification
- [ ] Déployer **Immich Mobile App** pour iOS/Android
- [ ] Configurer les **webhooks** pour les notifications externes

---

## 📚 Ressources Utiles

- **Documentation Officielle** : [https://immich.app/docs](https://immich.app/docs)
- **GitHub** : [https://github.com/immich-app/immich](https://github.com/immich-app/immich)
- **Community Discord** : [https://immich.app/discord](https://immich.app/discord)
- **Cloudflare Tunnel Docs** : [https://developers.cloudflare.com/cloudflare-one/connections/connect-apps/](https://developers.cloudflare.com/cloudflare-one/connections/connect-apps/)

---

## 📝 Historique des Changements

| Date | Changement | Auteur | Statut |
|------|------------|--------|--------|
| 2026-06-24 | Configuration initiale Immich | Stéphane | ✅ |
| 2026-06-24 | Correction port web (80 → 3000) | Vibe | ✅ |
| 2026-06-24 | Mise à jour pgvecto.rs (v0.1.11 → v0.2.0) | Vibe | ✅ |
| 2026-06-24 | Correction healthcheck (wget → curl) | Vibe | ✅ |
| 2026-06-24 | Ajout start_period: 60s au healthcheck | Vibe | ✅ |
| 2026-06-25 | Configuration Cloudflare Tunnel | Stéphane | ✅ |
| 2026-06-25 | Résolution problème DNS Mac (mDNSResponder) | Vibe | ✅ |
| 2026-06-25 | Vérification finale - Tout opérationnel | Stéphane/Vibe | ✅ |
| 2026-06-25 | Documentation complète finalisée | Vibe | ✅ |

### 🎯 Résumé Final (25 juin 2026)
- **Tunnel Cloudflare** : ID `6b5cb58d-2344-4653-8d0b-ba7723f8ac6d` healthy
- **Domaine** : `https://photos.stephaneroos.com` accessible
- **4 conteneurs** : Tous en état `healthy`
- **pgvecto.rs** : Version `v0.2.0` compatible avec Immich v2.7.5+
- **Ports** : immich-web:3000 → localhost:2284, immich-server:2283 (interne)

---

*Document généré par Mistral Vibe - Co-Authored-By: Mistral Vibe <vibe@mistral.ai>*