# Plan : Déconstruire Google & Gérer Données Perso

> **Objectifs** :
> 1. Migrer Google Photos → Immich sur NAS
> 2. Créer une interface unifiée pour gérer toutes les données perso
>
> **Date** : 25 juin 2026

---

## 📋 Table des matières

1. [Architecture cible](#architecture-cible)
2. [Objectif 1 : Google Photos → Immich](#objectif-1--google-photos--immich)
3. [Objectif 2 : Interface unifiée](#objectif-2--interface-unifiée)
4. [Plan d'action](#plan-daction)
5. [Ressources](#ressources)

---

## Architecture cible

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    TON ÉCOSYSTÈME SANS GOOGLE                               │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  ┌──────────────────────────────────────────────────────────────────────┐  │
│  │                    PORTAIL UNIFIÉ (Dashy)                             │  │
│  │                    https://home.stephaneroos.com                       │  │
│  │                                                                      │  │
│  │  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐             │  │
│  │  │ Immich   │  │Nextcloud │  │LADTC     │  │Forgejo   │             │  │
│  │  │ Photos   │  │ Docs     │  │Club     │  │Git       │             │  │
│  │  └──────────┘  └──────────┘  └──────────┘  └──────────┘             │  │
│  │                                                                      │  │
│  │  ┌──────────┐  ┌──────────┐  ┌──────────┐                         │  │
│  │  │Uptime    │  │Coolify   │  │Stats     │                         │  │
│  │  │Kuma      │  │Admin     │  │Monitoring│                         │  │
│  │  └──────────┘  └──────────┘  └──────────┘                         │  │
│  └──────────────────────────────────────────────────────────────────────┘  │
│                                                                             │
│  ┌──────────────────────────────────────────────────────────────────────┐  │
│  │                    STOCKAGE NAS (UGREEN)                              │  │
│  │                                                                      │  │
│  │  /mnt/nas/immich/library/     ← Photos/Vidéos                       │  │
│  │  /mnt/nas/nextcloud/data/     ← Documents                           │  │
│  │  /mnt/nas/backups/           ← Sauvegardes                         │  │
│  │  /mnt/nas/vaultwarden/       ← Mots de passe (option)              │  │
│  └──────────────────────────────────────────────────────────────────────┘  │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## Objectif 1 : Google Photos → Immich

### État actuel

- ✅ Immich configuré sur `/mnt/nas/immich/library/`
- ✅ Scripts de déploiement et migration existants
- ✅ Cloudflare Tunnel : `photos.stephaneroos.com`

### Processus de migration

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                WORKFLOW GOOGLE PHOTOS → IMMICH                              │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  1. GOOGLE TAKEOUT                                                          │
│     └─ https://takeout.google.com                                         │
│     └─ Sélectionner : "Photos only"                                       │
│     └─ Format : "Original quality"                                        │
│     └─ Inclure : Albums + Favorites                                       │
│     └─ Delivery : Download links (pas d'envoi email)                     │
│                                                                             │
│  2. TÉLÉCHARGEMENT                                                          │
│     └─ Télécharger les fichiers .zip                                     │
│     └─ Extraire dans un dossier temporaire                               │
│                                                                             │
│  3. PRÉTRAITEMENT (optionnel mais recommandé)                            │
│     └─ Corriger les dates EXIF (Google modifie les métadonnées)         │
│     └─ Script : exiftool                                                  │
│                                                                             │
│  4. IMPORT IMMICH                                                          │
│     └─ Utiliser immich-go (CLI tool)                                     │
│     └─ Préservation des albums + favorites                               │
│                                                                             │
│  5. VÉRIFICATION                                                            │
│     └─ Compter les photos importées                                       │
│     └─ Vérifier les albums                                                │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

### Outils nécessaires

#### 1. Google Takeout

**Étapes :**
1. Aller sur https://takeout.google.com
2. **Désélectionner tout**, puis ne sélectionner que "Photos"
3. Cliquer sur "All photo albums included" pour choisir les albums
4. **Important** : Cocher "Starred items" pour les favorites
5. Format : **"Original quality"** (pas compressé)
6. Delivery : **"Send download link via email"**
7. Taille max : **50GB par archive** (Google va créer plusieurs zips)

#### 2. immich-go (outil d'import)

**Installation :**
```bash
# Sur le serveur homelab
wget https://github.com/simulot/immich-go/releases/latest/download/immich-go-linux-amd64
chmod +x immich-go-linux-amd64
sudo mv immich-go-linux-amd64 /usr/local/bin/immich-go
```

**Configuration :**
```bash
# Créer un fichier de config
cat > ~/.immich-go.yaml << 'EOF'
Server: "https://photos.stephaneroos.com"
ApiKey: "TA_CLÉ_API_IMMICH"
EOF
```

**Obtenir la clé API Immich :**
1. Aller sur https://photos.stephaneroos.com
2. Cliquer sur l'avatar → Paramètres d'administration
3. Scroll jusqu'à "API Keys"
4. Créer une nouvelle clé avec les permissions :
   - Read assets
   - Upload assets
   - Create albums

#### 3. Script d'import automatisé

```bash
#!/bin/bash
# scripts/import-google-photos.sh

set -euo pipefail

# Configuration
TAKEOUT_DIR="/mnt/nas/temp/google-takeout"
IMMICH_LIBRARY="/mnt/nas/immich/library"
LOG_FILE="/var/log/immich-google-import-$(date +%Y%m%d_%H%M%S).log"

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

log "=== DÉBUT IMPORT GOOGLE PHOTOS VERS IMMICH ==="

# 1. Vérifier que les dossiers existent
if [ ! -d "$TAKEOUT_DIR" ]; then
    log "Erreur: Dossier Takeout introuvable: $TAKEOUT_DIR"
    log "Télécharger d'abord depuis Google Takeout"
    exit 1
fi

# 2. Lister les fichiers zip
log "Fichiers zip trouvés :"
find "$TAKEOUT_DIR" -name "*.zip" -o - "*.tgz" | tee -a "$LOG_FILE"

# 3. Import avec immich-go
log "Import avec immich-go..."
immich-go import \
    --recursive \
    --albums \
    --favorite \
    --delete-after-import \
    "$TAKEOUT_DIR" 2>&1 | tee -a "$LOG_FILE"

log "=== IMPORT TERMINÉ ==="
log "Vérifier sur https://photos.stephaneroos.com"
log "Log : $LOG_FILE"
```

### Prétraitement EXIF (optionnel)

Google modifie les dates EXIF. Pour les corriger :

```bash
# Installer exiftool
sudo apt install libimage-exiftool-perl

# Script de correction
cat > scripts/fix-google-photos-dates.sh << 'EOF'
#!/bin/bash
# Corrige les dates EXIF basées sur le nom de fichier Google (YYYY-MM-DD...)

find . -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" \) | while read file; do
    # Extraire la date du nom de fichier Google
    if [[ $file =~ ([0-9]{4}-[0-9]{2}-[0-9]{2}) ]]; then
        date="${BASH_REMATCH[1]}"
        exiftool -DateTimeOriginal="$date 12:00:00" "$file"
    fi
done
EOF
```

### Temps estimé

| Étape | Durée |
|-------|-------|
| Google Takeout (préparation) | 5 min |
| Attente téléchargement | 1-48h (dépend volume) |
| Extraction des zips | 10-30 min |
| Import immich-go | 1-4h (débit USB/NAS) |
| Vérification | 15 min |

---

## Objectif 2 : Interface unifiée

### Solution : Dashy

**Pourquoi Dashy ?**
- ✅ Docker ready
- ✅ Configuration simple (YAML)
- ✅ Widgets, thèmes, icônes
- ✅ Status checking (intégration Uptime Kuma)
- ✅ Open source, actif

### Architecture Dashy

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                         DASHY ARCHITECTURE                                  │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  ┌─────────────────┐    ┌─────────────────┐    ┌─────────────────────────┐ │
│  │   Dashy         │    │  Configuration  │    │      Services           │ │
│  │   (Docker)      │◄───│  YAML          │    │  (Cloudflare Tunnel)   │ │
│  │   Port: 4000    │    │  ~/.dashy/conf │    │                         │ │
│  └─────────────────┘    └─────────────────┘    └─────────────────────────┘ │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

### Docker Compose Dashy

```yaml
# configs/docker/dashy.yml
version: '3.8'

services:
  dashy:
    image: lissy93/dashy:latest
    container_name: dashy
    restart: unless-stopped
    ports:
      - "127.0.0.1:4000:80"
    volumes:
      # Configuration persistante
      - /mnt/nas/dashy/config:/app/public/data
      # Ou en local :
      # - dashy_config:/app/public/data
    environment:
      - TZ=Europe/Paris
    networks:
      - homelab-network

volumes:
  dashy_config:

networks:
  homelab-network:
    external: true
```

### Configuration Dashy (exemples)

```yaml
# ~/.dashy/conf/config.yml

pageTitle: Portail Stéphane
icon: fas fa-home
theme: River
headerStyle: clean
language: fr
layout: auto

# Sections
sections:
  - name: Photos & Documents
    icon: fas fa-images
    items:
      - title: Immich (Photos)
        description: Google Photos alternative
        url: https://photos.stephaneroos.com
        icon: https://immich.app/favicon.ico
        target: newtab

      - title: Nextcloud (Documents)
        description: Stockage cloud
        url: https://cloud.stephaneroos.com
        icon: https://nextcloud.com/favicon.ico
        target: newtab

  - name: Projects
    icon: fas fa-code
    items:
      - title: LADTC (Club Trail)
        description: Site web du club
        url: https://ladtc.be
        icon: https://ladtc.be/favicon.ico

      - title: Forgejo
        description: Git self-hosted
        url: https://git.anthemion.dev
        icon: https://forgejo.org/favicon.ico

  - name: Administration
    icon: fas fa-tools
    items:
      - title: Coolify
        description: Déploiement apps
        url: https://coolify.tondomain.com

      - title: Uptime Kuma
        description: Monitoring
        url: https://status.tondomain.com

      - title: Statistiques NAS
        description: UGREEN NAS
        url: http://192.168.129.21
```

### Cloudflare Tunnel pour Dashy

```bash
# Ajouter la route
cloudflared tunnel route docker dashy 4000

# DNS : home.stephaneroos.com → tunnel-id.cfargotunnel.com
```

---

## Plan d'action

### Phase 1 : Préparation Immich (1-2 heures)

- [ ] Vérifier Immich opérationnel
- [ ] Installer immich-go
- [ ] Générer clé API Immich
- [ ] Tester import avec quelques photos

**Commandes :**
```bash
# Sur homelab
ssh homelab

# Vérifier Immich
docker ps | grep immich

# Installer immich-go
wget https://github.com/simulot/immich-go/releases/latest/download/immich-go-linux-amd64
chmod +x immich-go-linux-amd64
sudo mv immich-go-linux-amd64 /usr/local/bin/immich-go

# Configurer
cat > ~/.immich-go.yaml << 'EOF'
Server: "https://photos.stephaneroos.com"
ApiKey: "RÉCUPÉRER_DANS_IMMICH"
EOF
```

### Phase 2 : Google Takeout (5 min + attente)

- [ ] Aller sur Google Takeout
- [ ] Sélectionner Photos only
- [ ] Inclure Albums + Favorites
- [ **Choisir "Original quality"**
- [ ] Demander download links

### Phase 3 : Téléchargement & Extraction (1-48h)

- [ ] Télécharger les zips sur le Mac
- [ ] Transférer vers `/mnt/nas/temp/google-takeout`
- [ ] Extraire tous les zips
- [ ] (Optionnel) Corriger les dates EXIF

```bash
# Sur Mac après téléchargement
scp -r Downloads/Takeout* homelab:/mnt/nas/temp/google-takeout

# Sur homelab
ssh homelab
cd /mnt/nas/temp/google-takeout
# Décompresser
find . -name "*.zip" -exec unzip {} \;
```

### Phase 4 : Import Immich (1-4h)

- [ ] Lancer le script d'import
- [ ] Surveiller les logs
- [ ] Vérifier l'import en cours

```bash
# Sur homelab
cd /home/steph/homelab
chmod +x scripts/import-google-photos.sh
./scripts/import-google-photos.sh

# Surveiller
tail -f /var/log/immich-google-import-*.log
```

### Phase 5 : Déploiement Dashy (1 heure)

- [ ] Créer `configs/docker/dashy.yml`
- [ ] Démarrer Dashy
- [ ] Configurer Cloudflare Tunnel
- [ ] Personnaliser l'interface

```bash
# Sur homelab
cd /home/steph/homelab/configs/docker
docker-compose -f dashy.yml up -d

# Configurer tunnel
cloudflared tunnel route docker dashy 4000
```

### Phase 6 : Vérification & Finitions (30 min)

- [ ] Vérifier toutes les photos importées
- [ ] Tester Dashy depuis mobile
- [ ] Configurer les widgets Dashy
- [ ] Documenter les comptes Google à supprimer

---

## Ressources

### Google Photos → Immich

- [Migrating to Immich from Google Photos](https://tsmith.com/blog/2025/immich-migration/) — Guide complet
- [Import Google Photos Takeout into Immich](https://www.devroom.io/2024/03/21/import-google-photos-takeout-into-immich/) — Avec immich-go
- [immich-go GitHub](https://github.com/simulot/immich-go) — Outil d'import

### Dashy

- [Dashy Site Officiel](https://dashy.to/)
- [Dashy GitHub](https://github.com/lissy93/dashy)
- [Awesome Self-Hosted Dashboards](https://awesome-selfhosted.net/tags/personal-dashboards.html)

### Architecture existante

- [Immich Homelab Guide](/Users/stephane/Projects/homelab/Documents/immich-homelab-guide.md)
- [Nextcloud AIO Config](/Users/stephane/Projects/homelab/configs/docker/nextcloud-aio.yml)

---

## Checklists

### Checklist Google Takeout

- [ ] Se connecter à Google Takeout
- [ ] Désélectionner tout
- [ ] Sélectionner "Photos" seulement
- [ ] Cliquer "All photo albums included"
- [ ] Sélectionner les albums (ou tous)
- [ ] ⭐ Cocher "Starred items"
- [ ] Choisir "Original quality"
- [ ] Choisir "Send download link via email"
- [ ] Soumettre la demande

### Checklist Post-Import

- [ ] Compter les photos : Google Photos vs Immich
- [ ] Vérifier les albums sont présents
- [ ] Vérifier les favorites (⭐) sont importées
- [ ] Tester la reconnaissance faciale
- [ ] Configurer le backup mobile (Android/iOS)
- [ ] Désactiver la sync Google Photos sur mobile

### Checklist Dashy

- [ ] Dashy accessible via https://home.stephaneroos.com
- [ ] Tous les services configurés
- [ ] Status checking actif
- [ ] Mobile responsive
- [ ] Thème personnalisé

---

**Date de création** : 25 juin 2026
**Prêt pour implémentation** : Oui
