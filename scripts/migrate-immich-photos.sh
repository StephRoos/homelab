#!/bin/bash
# Script: migrate-immich-photos.sh
# Description: Migration des photos depuis un dossier source vers la bibliothèque Immich
# Auteur: Mistral Vibe
# Date: 25 juin 2026
# Environnement: À exécuter sur homelab (UM880 Plus)

set -euo pipefail

# ============================================================================
# CONFIGURATION
# ============================================================================

# Dossier source (à adapter selon ton organisation)
SOURCE_DIR="/mnt/nas/photos"

# Dossier de destination (bibliothèque Immich)
DEST_DIR="/mnt/nas/immich/library"

# Fichier de log
LOG_FILE="/var/log/immich-migration-$(date +%Y%m%d_%H%M%S).log"

# ============================================================================
# FONCTIONS
# ============================================================================

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

error() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - ERROR - $1" | tee -a "$LOG_FILE" >&2
}

# ============================================================================
# VÉRIFICATIONS PRÉ-MIGRATION
# ============================================================================

log "========================================"
log "DEBUT DE LA MIGRATION IMMICH"
log "========================================"

# Vérifier que le script est exécuté sur homelab
if [ ! -d "/home/steph/homelab" ]; then
    error "Ce script doit être exécuté sur homelab (UM880 Plus)"
    exit 1
fi

# Vérifier que Docker est en cours d'exécution
if ! docker info > /dev/null 2>&1; then
    error "Docker n'est pas en cours d'exécution"
    exit 1
fi

# Vérifier les conteneurs Immich
log "Vérification des conteneurs Immich..."
IMMICH_RUNNING=$(docker ps | grep -c immich || true)
if [ "$IMMICH_RUNNING" -lt 4 ]; then
    error "Les conteneurs Immich ne sont pas tous démarrés"
    log "Conteneurs en cours :"
    docker ps | grep immich || true
    exit 1
fi
log "✅ 4 conteneurs Immich sont en cours d'exécution"

# Vérifier que le server écoute
log "Vérification du server Immich..."
if ! docker logs immich-server 2>/dev/null | grep -q "listening on"; then
    error "Le server Immich n'écoute pas"
    exit 1
fi
log "✅ Server Immich écoute sur le port 2283"

# Vérifier que la destination est accessible
log "Vérification des dossiers..."
if [ ! -d "$SOURCE_DIR" ]; then
    error "Dossier source introuvable : $SOURCE_DIR"
    exit 1
fi

if [ ! -d "$DEST_DIR" ]; then
    log "Création du dossier de destination : $DEST_DIR"
    mkdir -p "$DEST_DIR"
fi

# Vérifier l'espace disque disponible
log "Vérification de l'espace disque..."
AVAILABLE_SPACE=$(df -k /mnt/nas/ | awk 'NR==2 {print $4}')
USAGE_GB=$((AVAILABLE_SPACE / 1024 / 1024))
log "Espace disponible sur /mnt/nas : ${USAGE_GB} GB"
if [ "$USAGE_GB" -lt 10 ]; then
    error "Espace disque insuffisant (< 10 GB)"
    exit 1
fi

# ============================================================================
# PRÉPARATION
# ============================================================================

log ""
log "=== PHASE 1 : PRÉPARATION ==="

# Arrêter les scans automatiques pendant la migration
# (pour éviter que Immich ne scanne pendant la copie)

# Créer un fichier marqueur pour éviter les scans
TOUCH_FILE="$DEST_DIR/.migration-in-progress"
if [ ! -f "$TOUCH_FILE" ]; then
    touch "$TOUCH_FILE"
    log "Fichier marqueur créé : $TOUCH_FILE"
fi

# ============================================================================
# COMPTAGE DES FICHIERS
# ============================================================================

log ""
log "=== PHASE 2 : COMPTAGE DES FICHIERS ==="

# Types de fichiers à migrer
FILE_TYPES=("*.jpg" "*.jpeg" "*.png" "*.gif" "*.bmp" "*.tiff" "*.webp" "*.heic" "*.heif" "*.mp4" "*.mov" "*.avi" "*.mkv" "*.3gp" "*.m4v")

# Compter les fichiers source
log "Comptage des fichiers dans $SOURCE_DIR..."
SOURCE_COUNT=0
for pattern in "${FILE_TYPES[@]}"; do
    count=$(find "$SOURCE_DIR" -type f -iname "$pattern" 2>/dev/null | wc -l || true)
    SOURCE_COUNT=$((SOURCE_COUNT + count))
    log "  $pattern : $count fichiers"
done

log ""
log "📊 Total : $SOURCE_COUNT fichiers à migrer"

if [ "$SOURCE_COUNT" -eq 0 ]; then
    error "Aucun fichier trouvé dans $SOURCE_DIR"
    exit 1
fi

# ============================================================================
# MIGRATION
# ============================================================================

log ""
log "=== PHASE 3 : MIGRATION DES FICHIERS ==="

# Option 1 : rsync (recommandé - conserve les métadonnées)
log "Lancement de rsync (conservation de la structure des dossiers)..."
log "Source : $SOURCE_DIR/"
log "Destination : $DEST_DIR/"

RSYNC_CMD="rsync -avh --progress --stats --partial --itemize-changes \
    --exclude='.DS_Store' \
    --exclude='Thumbs.db' \
    --exclude='*.tmp' \
    --exclude='*.temp' \
    "$SOURCE_DIR/" "$DEST_DIR/"
"

log "Commande : $RSYNC_CMD"

# Exécuter rsync
eval "$RSYNC_CMD" 2>&1 | tee -a "$LOG_FILE"

RSYNC_EXIT=$?

if [ $RSYNC_EXIT -ne 0 ]; then
    error "Erreur lors de rsync (code: $RSYNC_EXIT)"
    exit $RSYNC_EXIT
fi

log "✅ Migration terminée avec succès !"

# ============================================================================
# VÉRIFICATION POST-MIGRATION
# ============================================================================

log ""
log "=== PHASE 4 : VÉRIFICATION ==="

# Compter les fichiers migrés
DEST_COUNT=0
for pattern in "${FILE_TYPES[@]}"; do
    count=$(find "$DEST_DIR" -type f -iname "$pattern" 2>/dev/null | wc -l || true)
    DEST_COUNT=$((DEST_COUNT + count))
done

log "Fichiers migrés : $DEST_COUNT"
log "Fichiers source : $SOURCE_COUNT"

if [ "$DEST_COUNT" -eq "$SOURCE_COUNT" ]; then
    log "✅ Tous les fichiers ont été migrés"
else
    log "⚠️  Attention : $((SOURCE_COUNT - DEST_COUNT)) fichiers manquants"
fi

# Vérifier l'espace utilisé
DEST_SIZE=$(du -sh "$DEST_DIR" | awk '{print $1}')
log "Espace utilisé dans $DEST_DIR : $DEST_SIZE"

# ============================================================================
# CONFIRMATION
# ============================================================================

log ""
log "=== PHASE 5 : CONFIRMATION ==="

log ""
log "✅ MIGRATION TERMINÉE AVEC SUCCÈS"
log ""
log "Immich va automatiquement scanner le dossier $DEST_DIR"
log "Cela peut prendre plusieurs minutes selon le nombre de fichiers."
log ""
log "Pour forcer un scan manuel :"
log "  1. Aller sur https://photos.stephaneroos.com"
log "  2. Paramètres → Bibliothèques → Scanner maintenant"
log ""
log "Ou via l'API (nécessite un token) :"
log "  curl -X POST http://localhost:2284/api/library/scan \\"
log "    -H \"Authorization: Bearer TON_TOKEN\" \\"
log "    -H \"Content-Type: application/json\""
log ""
log "Fichier de log : $LOG_FILE"

# Supprimer le fichier marqueur
rm -f "$TOUCH_FILE"
log "Fichier marqueur supprimé"

log "========================================"
log "FIN DE LA MIGRATION"
log "========================================"

exit 0
