# Homelab Architecture 2026 - Guide Complet

> **Guide de référence pour une architecture production-ready**
> **Date** : 25 juin 2026
> **Version** : 1.0

---

## Table des Matières

1. [Vue d'ensemble](#vue-densemble)
2. [Architecture recommandée](#architecture-recommandée)
3. [Reverse Proxy : Comparatif complet](#reverse-proxy--comparatif-complet)
4. [Hébergement Web Public (ladtc.be)](#hébergement-web-public-ladtcbe)
5. [Stockage Cloud (Nextcloud & Immich)](#stockage-cloud-nextcloud--immich)
6. [Sécurité production-ready](#sécurité-production-ready)
7. [Monitoring & Observabilité](#monitoring--observabilité)
8. [Stratégie de Backup](#stratégie-de-backup)
9. [Recommandations finales](#recommandations-finales)

---

## Vue d'ensemble

### Besoins identifiés

```
┌─────────────────────────────────────────────────────────────┐
│                    HOMELAB 2026                              │
├──────────────────────┬──────────────────────────────────────┤
│     Public Web      │         Données Perso                 │
├──────────────────────┼──────────────────────────────────────┤
│ • ladtc.be (WordPress)│ • Nextcloud (fichiers)                │
│ • Autres sites web   │ • Immich (photos)                     │
│ • Forgejo (Git)      │ • Vaultwarden (mots de passe)         │
└──────────────────────┴──────────────────────────────────────┘
```

### Contraintes

- **Sécurité** : WAF, SSL/TLS, protection DDoS
- **Performance** : Latence minimale pour les données perso
- **Fiabilité** : Backups automatisés, monitoring
- **Indépendance** : Minimiser les dépendances externes

---

## Architecture recommandée

### Schéma global

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                         ARCHITECTURE HOMELAB 2026                            │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  ┌──────────────┐        ┌──────────────────────────────────────────────┐ │
│  │   Internet   │        │              COUCHES RÉSEAUX                   │ │
│  └──────┬───────┘        ├──────────────┬─────────────┬──────────────────┤ │
│         │                │              │             │                  │ │
│         ▼                │   Public     │   Privé     │   Management     │ │
│  ┌──────────────┐        │   (80/443)   │   (VPN)     │   (SSH)          │ │
│  │  Cloudflare │        │              │             │                  │ │
│  │  (optionnel)│        └──────────────┴─────────────┴──────────────────┘ │
│  └──────┬───────┘                                                       │
│         │                                                                │
│         ▼                                                                │
│  ┌────────────────────────────────────────────────────────────────────┐  │
│  │                    REVERSE PROXY (Caddy/Traefik)                   │  │
│  │                        + Let's Encrypt                             │  │
│  └────────────────────────────────────────────────────────────────────┘  │
│                              │                                            │
│         ┌────────────────────┼────────────────────┐                      │
│         ▼                    ▼                    ▼                      │
│  ┌──────────┐         ┌──────────┐         ┌──────────┐                  │
│  │  Public  │         │  Privé   │         │   Admin  │                  │
│  │          │         │          │         │          │                  │
│  │ ladtc.be │         │Immich   │         │Coolify   │                  │
│  │WordPress │         │Nextcloud│         │Grafana   │                  │
│  │Forgejo   │         │Vaultward│         │Prometheus │                  │
│  └──────────┘         └──────────┘         └──────────┘                  │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## Reverse Proxy : Comparatif complet

### Tableau comparatif

| Solution | Ports ouverts | Auto HTTPS | WAF/CDN | Complexité | Indépendance | Performance |
|----------|---------------|------------|---------|------------|--------------|-------------|
| **Caddy** | 80/443 | ✅ Natif (Let's Encrypt) | ❌ Non | ⭐ Faible | ✅ Totale | ⭐⭐⭐⭐⭐ |
| **Traefik** | 80/443 | ✅ Natif | ❌ Non | ⭐⭐ Moyenne | ✅ Totale | ⭐⭐⭐⭐⭐ |
| **Nginx Proxy Manager** | 80/443 | ✅ UI | ❌ Non | ⭐ Faible | ✅ Totale | ⭐⭐⭐⭐ |
| **Cloudflare Tunnel** | ❌ Aucun | ✅ Cloudflare | ✅ Inclus | ⭐ Faible | ❌ Dépendant | ⭐⭐⭐ |
| **Nginx manuel** | 80/443 | ⚠️ Certbot | ❌ Non | ⭐⭐⭐ Élevée | ✅ Totale | ⭐⭐⭐⭐⭐ |

### Recommandation 2026 : Caddy

**Pourquoi Caddy ?**

1. **HTTPS automatique natif** — Pas de configuration complexe
2. **Configuration simple** — JSON ou Caddyfile, très lisible
3. **Modern web server** — Support HTTP/2, HTTP/3 par défaut
4. **Sécurité** — Perfect Forward Secrecy, cipher suites modernes
5. **Performance** — écrit en Go, très rapide
6. **Reverse proxy natif** — pas besoin de modules supplémentaires

**Exemple de configuration Caddyfile**

```caddyfile
# ladtc.be - Site public
ladtc.be {
    root * /var/www/wordpress
    php_fastcgi localhost:9000
    file_server
    encode zstd gzip

    # Security headers
    header {
        X-Frame-Options "SAMEORIGIN"
        X-Content-Type-Options "nosniff"
        X-XSS-Protection "1; mode=block"
        Referrer-Policy "strict-origin-when-cross-origin"
        Permissions-Policy "geolocation=(), microphone=(), camera=()"
    }

    # Logs
    log {
        output file /var/log/caddy/ladtc.log
        format json
    }
}

# photos.stephaneroos.com - Immich
photos.stephaneroos.com {
    reverse_proxy localhost:2283 {
        header_up Host {host}
        header_up X-Real-IP {remote_host}
        header_up X-Forwarded-For {remote_host}
        header_up X-Forwarded-Proto {scheme}
    }
}

# cloud.stephaneroos.com - Nextcloud
cloud.stepphaneroos.com {
    reverse_proxy localhost:11000

    # Nextcloud specific
    header {
        # Strict-Transport-Security "max-age=31536000;"
        X-Frame-Options "SAMEORIGIN"
    }
}

# Administration - Accès IP restreint
admin.stephaneroos.com {
    reverse_proxy localhost:3001

    # IP whitelist (adapter avec ton IP)
    @allowed from 192.168.0.0/16
    handle @allowed {
        reverse_proxy localhost:3001
    }
    handle {
        respond "Forbidden" 403
    }
}
```

---

## Hébergement Web Public (ladtc.be)

### Stack WordPress production

```
┌─────────────────────────────────────────────────────────────┐
│                    WORDPRESS PRODUCTION                      │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  ┌──────────┐    ┌──────────┐    ┌──────────────────────┐  │
│  │  Caddy   │───►│  PHP-FPM │───►│   WordPress + MySQL   │  │
│  │   :443   │    │  :9000   │    │      (Docker)         │  │
│  └──────────┘    └──────────┘    └──────────────────────┘  │
│                                                              │
│  ┌────────────────────────────────────────────────────────┐ │
│  │              SECURITY LAYER                             │ │
│  │  • WAF (Cloudflare optionnel)                          │ │
│  │  • Rate limiting (Caddy)                                │ │
│  │  • Fail2Ban (WordPress brute force)                    │ │
│  └────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
```

### Docker Compose recommandé

```yaml
version: '3.8'

services:
  wordpress:
    image: wordpress:latest
    container_name: ladtc-wordpress
    restart: unless-stopped
    volumes:
      - wordpress_data:/var/www/html
      - ./uploads.ini:/usr/local/etc/php/conf.d/uploads.ini
    environment:
      WORDPRESS_DB_HOST: db:3306
      WORDPRESS_DB_USER: ${DB_USER}
      WORDPRESS_DB_PASSWORD: ${DB_PASSWORD}
      WORDPRESS_DB_NAME: ladtc_db
      WORDPRESS_TABLE_PREFIX: ${WP_PREFIX}_  # Sécurité
    networks:
      - wordpress-network

  db:
    image: mysql:8.0
    container_name: ladtc-mysql
    restart: unless-stopped
    volumes:
      - mysql_data:/var/lib/mysql
    environment:
      MYSQL_DATABASE: ladtc_db
      MYSQL_USER: ${DB_USER}
      MYSQL_PASSWORD: ${DB_PASSWORD}
      MYSQL_ROOT_PASSWORD: ${DB_ROOT_PASSWORD}
    networks:
      - wordpress-network

  phpmyadmin:
    image: phpmyadmin:latest
    container_name: ladtc-phpmyadmin
    restart: unless-stopped
    environment:
      PMA_HOST: db
      PMA_PORT: 3306
      UPLOAD_LIMIT: 100M
    ports:
      - "8080:80"
    networks:
      - wordpress-network

volumes:
  wordpress_data:
  mysql_data:

networks:
  wordpress-network:
    driver: bridge
```

### Plugins WordPress essentiels (sécurité)

1. **Wordfence Security** — WAF, scan malware, login security
2. **Limit Login Attempts Reloaded** — Protection brute force
3. **Really Simple SSL** — HTTPS forcé
4. **WP Hide & Security Enhancer** — Masque WordPress
5. **UpdraftPlus** — Backups automatisés

---

## Stockage Cloud (Nextcloud & Immich)

### Nextcloud AIO vs Docker manuel

**Recommandation : Nextcloud AIO (All-in-One)**

Pourquoi ?
- Installation simplifiée
- Mises à jour automatisées
- Configuration sécurité pré-établie
- Support officiel

```bash
# Installation Nextcloud AIO
docker run -d \
  --name nextcloud-aio-mastercontainer \
  --restart always \
  --publish 8080:8080 \
  -e APACHE_PORT=11000 \
  -v nextcloud_aio_mastercontainer:/mnt/docker-aio-config \
  -v /var/run/docker.sock:/var/run/docker.sock:ro \
  nextcloud/all-in-one:latest
```

### Immich - Configuration production

**Architecture**

```
┌─────────────────────────────────────────────────────────────┐
│                      IMMICH STACK                            │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  ┌──────────┐    ┌──────────┐    ┌──────────────────────┐  │
│  │  Caddy   │───►│  Immich  │───►│    PostgreSQL         │  │
│  │   :443   │    │  :2283   │    │    (Base de données) │  │
│  └──────────┘    └──────────┘    └──────────────────────┘  │
│                                                              │
│  ┌────────────────────────────────────────────────────────┐ │
│  │                    REDIS (Cache)                         │ │
│  └────────────────────────────────────────────────────────┘ │
│                                                              │
│  ┌────────────────────────────────────────────────────────┐ │
│  │              TYPESENSE (Recherche)                       │ │
│  └────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
```

**Docker Compose production**

```yaml
version: "3.8"

services:
  immich:
    image: ghcr.io/immich-app/immich-server:release
    container_name: immich
    restart: unless-stopped
    ports:
      - "2283:3001"
    volumes:
      - ${UPLOAD_LOCATION}:/usr/src/app/upload
      - /etc/localtime:/etc/localtime:ro
    environment:
      - DB_HOSTNAME=postgres
      - DB_USERNAME=postgres
      - DB_PASSWORD=${DB_PASSWORD}
      - DB_DATABASE_NAME=immich
      - REDIS_HOSTNAME=immich-redis
      - TYPESENSE_URL=http://typesense:8108
    depends_on:
      - redis
      - database
      - typesense

  postgres:
    image: postgres:15
    container_name: immich-postgres
    restart: unless-stopped
    environment:
      POSTGRES_PASSWORD=${DB_PASSWORD}
      POSTGRES_DB=immich
    volumes:
      - pgdata:/var/lib/postgresql/data

  redis:
    image: redis:alpine
    container_name: immich-redis
    restart: unless-stopped

  typesense:
    image: typesense/typesense:0.24.0
    container_name: immich-typesense
    restart: unless-stopped
    environment:
      - TYPESENSE_API_KEY=${TYPESENSE_API_KEY}
    volumes:
      - typesense-data:/data

volumes:
  pgdata:
  typesense-data:
```

### Configuration Reverse Proxy pour Immich

**Headers requis (documentation officielle)**

```nginx
# Nginx
location / {
    proxy_pass http://localhost:2283;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;

    # Uploads de grande taille
    client_max_body_size 10000M;
}
```

```caddyfile
# Caddy
photos.stephaneroos.com {
    reverse_proxy localhost:2283

    # Caddy définit automatiquement les headers requis
    # X-Real-IP, X-Forwarded-For, X-Forwarded-Proto
}
```

---

## Sécurité production-ready

### Couches de sécurité

```
┌─────────────────────────────────────────────────────────────┐
│               COUCHES DE SÉCURITÉ                           │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  ┌────────────────────────────────────────────────────────┐ │
│  │  1. PARE-FEU UFW                                       │ │
│  │     • SSH: port 22 seulement (key-based)               │ │
│  │     • HTTP/HTTPS: 80, 443                              │ │
│  │     • Refuser tout le reste                            │ │
│  └────────────────────────────────────────────────────────┘ │
│                              ↓                                │
│  ┌────────────────────────────────────────────────────────┐ │
│  │  2. FAIL2BAN                                            │ │
│  │     • Protection brute force SSH                        │ │
│  │     • Protection WordPress                              │ │
│  │     • Protection Nextcloud                              │ │
│  └────────────────────────────────────────────────────────┘ │
│                              ↓                                │
│  ┌────────────────────────────────────────────────────────┐ │
│  │  3. CADDY (HTTPS FORCÉ)                                 │ │
│  │     • TLS 1.3 uniquement                               │ │
│  │     • Security headers                                  │ │
│  │     • Automatic HSTS                                   │ │
│  └────────────────────────────────────────────────────────┘ │
│                              ↓                                │
│  ┌────────────────────────────────────────────────────────┐ │
│  │  4. WAF (optionnel - Cloudflare)                        │ │
│  │     • OWASP ModSecurity                                │ │
│  │     • Rate limiting                                    │ │
│  │     • Bot protection                                   │ │
│  └────────────────────────────────────────────────────────┘ │
│                              ↓                                │
│  ┌────────────────────────────────────────────────────────┐ │
│  │  5. APPLICATION                                         │ │
│  │     • Mots de passe forts                               │ │
│  │     • 2FA activé                                       │ │
│  │     • Permissions restrictives                         │ │
│  └────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
```

### Script de durcissement UFW

```bash
#!/bin/bash
# harden-ufw.sh

# Reset
ufw --force reset

# Default policies
ufw default deny incoming
ufw default allow outgoing

# SSH (avec rate limiting)
ufw limit 22/tcp

# HTTP/HTTPS
ufw allow 80/tcp
ufw allow 443/tcp

# Docker networks
ufw allow from 172.16.0.0/12
ufw allow from 192.168.0.0/16

# Enable
ufw --force enable

echo "✅ UFW durci activé"
```

### Fail2ban - Configuration WordPress

```ini
[wordpress]
enabled = true
port = http,https
filter = wordpress
logpath = /var/log/caddy/ladtc.log
maxretry = 5
findtime = 60
bantime = 3600
```

---

## Monitoring & Observabilité

### Stack recommandée (GitHub: av1155/homelab)

```
┌─────────────────────────────────────────────────────────────┐
│              STACK MONITORING HOMELAB 2026                   │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  ┌──────────┐    ┌──────────┐    ┌──────────────────────┐  │
│  │ Prometheus│───►│ Grafana  │───►│   Dashboards         │  │
│  │ :9090    │    │ :3000    │    │   (Visualisation)    │  │
│  └──────────┘    └──────────┘    └──────────────────────┘  │
│                                                              │
│  ┌────────────────────────────────────────────────────────┐ │
│  │              EXPORTERS                                    │ │
│  │  • Node Exporter (métriques système)                   │ │
│  │  • cAdvisor (containers Docker)                         │ │
│  │  • Postgres Exporter (base de données)                 │ │
│  └────────────────────────────────────────────────────────┘ │
│                                                              │
│  ┌────────────────────────────────────────────────────────┐ │
│  │              ALERTING                                   │ │
│  │  • Uptime Kuma (uptime + alertes)                      │ │
│  │  • Alertmanager (Prometheus)                           │ │
│  └────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
```

### Docker Compose monitoring

```yaml
version: '3.8'

services:
  prometheus:
    image: prom/prometheus:latest
    container_name: prometheus
    restart: unless-stopped
    ports:
      - "9090:9090"
    volumes:
      - ./prometheus.yml:/etc/prometheus/prometheus.yml
      - prometheus_data:/prometheus
    command:
      - '--config.file=/etc/prometheus/prometheus.yml'
      - '--storage.tsdb.path=/prometheus'

  grafana:
    image: grafana/grafana:latest
    container_name: grafana
    restart: unless-stopped
    ports:
      - "3001:3000"
    environment:
      - GF_SECURITY_ADMIN_PASSWORD=${GRAFANA_PASSWORD}
    volumes:
      - grafana_data:/var/lib/grafana

  node-exporter:
    image: prom/node-exporter:latest
    container_name: node-exporter
    restart: unless-stopped
    ports:
      - "9100:9100"
    command:
      - '--path.rootfs=/host'
    volumes:
      - '/:/host:ro,rslave'

  uptime-kuma:
    image: louislam/uptime-kuma:latest
    container_name: uptime-kuma
    restart: unless-stopped
    ports:
      - "3001:3001"
    volumes:
      - uptime_data:/app/data

volumes:
  prometheus_data:
  grafana_data:
  uptime_data:
```

---

## Stratégie de Backup

### 3-2-1 Rule adaptée au homelab

```
┌─────────────────────────────────────────────────────────────┐
│                  RÈGLE 3-2-1 HOMELAB                         │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  3 copies de données                                         │
│  2 types de stockage différents                            │
│  1 copie hors-site (off-site)                               │
│                                                              │
│  ┌──────────┐    ┌──────────┐    ┌──────────────────────┐  │
│  │  PRIMAIRE│    │  SECONDAIRE│   │     OFF-SITE         │  │
│  │  (Local) │    │  (NAS)   │    │    (Cloud/Borg)      │  │
│  │           │    │          │    │                       │  │
│  │  Docker   │    │  NFS/SMB │    │  Backups chiffrés   │  │
│  │  volumes  │    │  sync    │    │  (Restic/Borg)       │  │
│  └──────────┘    └──────────┘    └──────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
```

### Script backup automatisé

```bash
#!/bin/bash
# backup-homelab.sh

# Variables
BACKUP_DIR="/backup/$(date +%Y%m%d)"
RETENTION=7  # jours
NAS_USER="backup"
NAS_HOST="192.168.129.21"
NAS_PATH"/mnt/backup/homelab"

# Créer répertoire
mkdir -p "$BACKUP_DIR"

# 1. Backup volumes Docker
echo "📦 Backup Docker volumes..."
docker run --rm \
  -v wordpress_data:/data \
  -v nextcloud_data:/data2 \
  -v immich_data:/data3 \
  -v "$BACKUP_DIR":/backup \
  alpine tar czf /backup/docker-volumes-$(date +%Y%m%d).tar.gz /data

# 2. Backup bases de données
echo "💾 Backup databases..."
docker exec ladtc-mysql mysqldump -u root -p"${DB_ROOT_PASSWORD}" ladtc_db > "$BACKUP_DIR/ladtc.sql"
docker exec immich-postgres pg_dump immich > "$BACKUP_DIR/immich.sql"

# 3. Backup configurations
echo "⚙️ Backup configurations..."
tar czf "$BACKUP_DIR/config-$(date +%Y%m%d).tar.gz" \
  /etc/caddy \
  /root/.coolify \
  /etc/cloudflared

# 4. Sync vers NAS
echo "🔄 Sync to NAS..."
rsync -avz --delete \
  "$BACKUP_DIR/" \
  "$NAS_USER@$NAS_HOST:$NAS_PATH/$(hostname)/"

# 5. Backup off-site (optionnel - Restic)
# restic -r rclone:b2:homelab-backups:/$(hostname) backup "$BACKUP_DIR"

# 6. Nettoyage anciens backups
echo "🧹 Clean old backups..."
find /backup -type d -mtime +$RETENTION -exec rm -rf {} \;

echo "✅ Backup terminé: $BACKUP_DIR"
```

### 10 choses à backuper absolument

D'après [VirtualizationHowto](https://www.virtualizationhowto.com/2025/11/10-things-you-should-back-up-in-your-home-lab-but-probably-dont/) :

1. **Fichiers de configuration** - `/etc/caddy`, docker-compose.yml
2. **Volumes Docker** - données des applications
3. **Données reverse proxy** - certificats SSL, configuration
4. **DNS zone data** - si DNS auto-hébergé
5. **Clés SSH** - `~/.ssh`
6. **Métriques Prometheus + dashboards Grafana**
7. **Secrets/Passwords** - de préférence dans un vault
8. **Données Nextcloud/Immich** - évidemment
9. **Base de données** - dumps réguliers
10. **Scripts d'administration** - dans un repo Git

---

## Recommandations finales

### Résumé de l'architecture proposée

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                         HOMELAB 2026 - RÉSUMÉ                               │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  🔌 REVERSE PROXY: Caddy (ports 80/443 ouverts, HTTPS auto)                 │
│                                                                             │
│  🌐 SERVICES PUBLICS (accès via Cloudflare optionnel):                      │
│     • ladtc.be (WordPress)                                                  │
│     • Forgejo (Git)                                                         │
│                                                                             │
│  📁 SERVICES PRIVÉS (accès local):                                          │
│     • Immich (photos.stephaneroos.com)                                     │
│     • Nextcloud (cloud.stephaneroos.com)                                   │
│     • Vaultwarden                                                           │
│                                                                             │
│  📊 MONITORING:                                                             │
│     • Prometheus + Grafana                                                  │
│     • Uptime Kuma                                                           │
│     • Dozzle (logs containers)                                              │
│                                                                             │
│  💾 BACKUPS:                                                                 │
│     • Local → NAS (automatisé)                                              │
│     • Off-site (optionnel: Restic + Backblaze B2)                           │
│                                                                             │
│  🔒 SÉCURITÉ:                                                               │
│     • UFW + Fail2Ban                                                        │
│     • Caddy (TLS 1.3, HSTS)                                                 │
│     • WAF Cloudflare (optionnel)                                            │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

### Avantages de cette architecture

1. **Indépendance** — Caddy ne dépend de personne
2. **Performance** — Latence minimale pour services locaux
3. **Sécurité** — HTTPS automatique, headers modernes
4. **Simplicité** — Configuration Caddy très lisible
5. **Flexibilité** — Peut ajouter Cloudflare devant si nécessaire
6. **Monitoring** — Observabilité complète

### Migration progressive depuis Cloudflare Tunnel

**Phase 1** : Installer Caddy parallèle à Cloudflare
```bash
# Docker
docker run -d --name caddy \
  -p 80:80 -p 443:443 \
  -v caddy_data:/data \
  -v Caddyfile:/etc/caddy/Caddyfile \
  caddy:latest
```

**Phase 2** : Migrer un service à la fois
1. Configurer Caddy pour un service
2. Ouvrir ports 80/443 sur UFW
3. Tester en local
4. Mettre à jour DNS (pointervers IP)
5. Vérifier HTTPS automatique
6. Désactiver route Cloudflare Tunnel

**Phase 3** : Une fois stable, retirer Cloudflare Tunnel

---

## Sources

- [Immich Reverse Proxy Documentation](https://docs.immich.app/administration/reverse-proxy)
- [Nextcloud Reverse Proxy Configuration](https://docs.nextcloud.com/server/stable/admin_manual/configuration_server/reverse_proxy_configuration.html)
- [Traefik Docker Swarm Setup](https://doc.traefik.io/traefik/setup/swarm/)
- [Why I ditched Cloudflare Tunnels for Caddy](https://www.xda-developers.com/why-i-ditched-cloudflare-tunnels-for-tailscale-and-caddy-on-my-homelab/)
- [Automatic HTTPS with Caddy and Cloudflare](https://samedwardes.com/blog/2023-11-19-homelab-tls-with-caddy-and-cloudflare/)
- [10 Things to Back Up in Your Home Lab](https://www.virtualizationhowto.com/2025/11/10-things-you-should-back-up-in-your-home-lab-but-probably-dont/)
- [Production-Grade Homelab (GitHub: av1155/homelab)](https://github.com/av1155/homelab)
- [Homelab Essential Services 2026](https://readthemanual.co.uk/homelab-essential-services-2025-build-your-full-stack/)
- [Cloudflare Tunnel vs Nginx Proxy Manager](https://noted.lol/cloudflare-tunnels-vs-nginx-proxy-manager/)

---

## Notes

- Ce guide est basé sur les meilleures pratiques 2026
- L'architecture proposée est évolutive et modulaire
- La sécurité en couches (defense in depth) est privilégiée
- Les backups automatisés sont indispensables
- Le monitoring permet une réaction rapide aux problèmes

**Prochaine étape** : Définir un plan de migration progressif si adoption de Caddy
