#!/bin/bash
# Script: backup-immich.sh
# Description: Sauvegarde complète de la configuration Immich
# Auteur: Mistral Vibe
# Date: 25 juin 2026
# Environnement: À exécuter sur homelab (UM880 Plus)

set -euo pipefail

# ============================================================================
# CONFIGURATION
# ============================================================================

# Répertoire de sauvegarde
BACKUP_DIR="/mnt/nas/backups/immich"

# Date pour les noms de fichiers
DATE=$(date +%Y%m%d_%H%M%S)

# Fichier de log
LOG_FILE="$BACKUP_DIR/backup-immich-$DATE.log"

# Répertoire temporaire
TMP_DIR=$(mktemp -d)

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
# VÉRIFICATIONS PRÉ-BACKUP
# ============================================================================

log "========================================"
log "DEBUT DE LA SAUVEGARDE IMMICH"
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

# Créer le répertoire de sauvegarde
log "Création du répertoire de sauvegarde : $BACKUP_DIR"
mkdir -p "$BACKUP_DIR"

# Vérifier l'espace disque disponible
log "Vérification de l'espace disque..."
AVAILABLE_SPACE=$(df -k /mnt/nas/ | awk 'NR==2 {print $4}')
USAGE_GB=$((AVAILABLE_SPACE / 1024 / 1024))
log "Espace disponible sur /mnt/nas : ${USAGE_GB} GB"
if [ "$USAGE_GB" -lt 5 ]; then
    error "Espace disque insuffisant (< 5 GB) pour la sauvegarde"
    exit 1
fi

# ============================================================================
# SAUVEGARDE DE LA BASE DE DONNÉES
# ============================================================================

log ""
log "=== SAUVEGARDE DE LA BASE DE DONNÉES ==="

DB_BACKUP_FILE="$BACKUP_DIR/immich-db-$DATE.sql"

log "Démarrage du dump PostgreSQL..."
log "Destination : $DB_BACKUP_FILE"

# Exécuter pg_dump via docker
docker exec immich-postgres pg_dump -U immich -d immich > "$DB_BACKUP_FILE" 2>"$LOG_FILE"

if [ ! -s "$DB_BACKUP_FILE" ]; then
    error "Échec de la sauvegarde de la base de données"
    rm -f "$DB_BACKUP_FILE"
    exit 1
fi

DB_SIZE=$(du -h "$DB_BACKUP_FILE" | awk '{print $1}')
log "✅ Sauvegarde DB terminée : $DB_SIZE"

# ============================================================================
# SAUVEGARDE DE LA CONFIGURATION
# ============================================================================

log ""
log "=== SAUVEGARDE DE LA CONFIGURATION ==="

CONFIG_BACKUP_FILE="$BACKUP_DIR/immich-config-$DATE.tar.gz"

log "Compression de la configuration..."
log "Source : /mnt/nas/immich/config"
log "Destination : $CONFIG_BACKUP_FILE"

tar -czvf "$CONFIG_BACKUP_FILE" /mnt/nas/immich/config 2>>"$LOG_FILE"

if [ ! -s "$CONFIG_BACKUP_FILE" ]; then
    error "Échec de la sauvegarde de la configuration"
    rm -f "$CONFIG_BACKUP_FILE"
    exit 1
fi

CONFIG_SIZE=$(du -h "$CONFIG_BACKUP_FILE" | awk '{print $1}')
log "✅ Sauvegarde config terminée : $CONFIG_SIZE"

# ============================================================================
# SAUVEGARDE DES STATISTIQUES
# ============================================================================

log ""
log "=== SAUVEGARDE DES STATISTIQUES ==="

# Créer un fichier info avec les statistiques
INFO_FILE="$BACKUP_DIR/immich-info-$DATE.txt"

{
    echo "========================================"
    echo "SAUVEGARDE IMMICH - $DATE"
    echo "========================================"
    echo ""
    echo "Environnement :"
    echo "  Hôte : $(hostname)"
    echo "  Date : $(date)"
    echo ""
    echo "Conteneurs Docker :"
    docker ps | grep immich || true
    echo ""
    echo "Versions :"
    echo "  immich-server : $(docker inspect immich-server --format='{{.Config.Image}}')"
    echo "  immich-web : $(docker inspect immich-web --format='{{.Config.Image}}')"
    echo "  immich-postgres : $(docker inspect immich-postgres --format='{{.Config.Image}}')"
    echo ""
    echo "Espace disque :"
    df -h /mnt/nas/
    echo ""
    echo "Taille de la bibliothèque :"
    du -sh /mnt/nas/immich/library || true
    echo ""
    echo "Fichiers dans la bibliothèque :"
    find /mnt/nas/immich/library -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.mp4" \) | wc -l || true
    echo ""
} > "$INFO_FILE" 2>>"$LOG_FILE"

log "✅ Fichier d'info créé : $INFO_FILE"

# ============================================================================
# SAUVEGARDE DES VOLUMES DOCKER (Optionnel)
# ============================================================================

log ""
log "=== SAUVEGARDE DES VOLUMES DOCKER ==="

# Sauvegarder les volumes Docker (postgres-data et redis-data)
VOLUME_BACKUP_DIR="$BACKUP_DIR/volumes-$DATE"
mkdir -p "$VOLUME_BACKUP_DIR"

log "Sauvegarde des volumes Docker..."

# Sauvegarder immich-postgres-data
docker run --rm \
    --volumes-from immich-postgres \
    -v "$VOLUME_BACKUP_DIR:/backup" \
    alpine \
    sh -c "cd /var/lib/postgresql/data && tar -czvf /backup/immich-postgres-data-$DATE.tar.gz ." \
    >> "$LOG_FILE" 2>&1

# Sauvegarder immich-redis-data
docker run --rm \
    --volumes-from immich-redis \
    -v "$VOLUME_BACKUP_DIR:/backup" \
    alpine \
    sh -c "cd /data && tar -czvf /backup/immich-redis-data-$DATE.tar.gz ." \
    >> "$LOG_FILE" 2>&1

VOLUME_SIZE=$(du -sh "$VOLUME_BACKUP_DIR" | awk '{print $1}')
log "✅ Sauvegarde des volumes terminée : $VOLUME_SIZE"

# ============================================================================
# VÉRIFICATION
# ============================================================================

log ""
log "=== VÉRIFICATION DES SAUVEGARDES ==="

# Lister les fichiers créés
log "Fichiers de sauvegarde créés :"
ls -lh "$BACKUP_DIR"/immich-*

# Calculer la taille totale
total_size=$(du -sh "$BACKUP_DIR" | awk '{print $1}')
log "Taille totale de la sauvegarde : $total_size"

# ============================================================================
# NETTOYAGE
# ============================================================================

log ""
log "=== NETTOYAGE ==="

# Supprimer les sauvegardes de plus de 30 jours
log "Suppression des sauvegardes de plus de 30 jours..."
find "$BACKUP_DIR" -name "immich-*.sql" -mtime +30 -delete 2>/dev/null
find "$BACKUP_DIR" -name "immich-*.tar.gz" -mtime +30 -delete 2>/dev/null
find "$BACKUP_DIR" -name "immich-*.txt" -mtime +30 -delete 2>/dev/null
find "$BACKUP_DIR" -type d -name "volumes-*" -mtime +30 -exec rm -rf {} + 2>/dev/null

log "Nettoyage terminé"

# Supprimer le répertoire temporaire
rm -rf "$TMP_DIR"

# ============================================================================
# CONFIRMATION
# ============================================================================

log ""
log "=== CONFIRMATION ==="

log ""
log "✅ SAUVEGARDE TERMINÉE AVEC SUCCÈS"
log ""
log "Fichiers créés dans : $BACKUP_DIR"
log "  - Base de données : immich-db-$DATE.sql"
log "  - Configuration : immich-config-$DATE.tar.gz"
log "  - Informations : immich-info-$DATE.txt"
log "  - Volumes : volumes-$DATE/"
log ""
log "Fichier de log : $LOG_FILE"
log ""
log "Pour restaurer, utiliser le script restore-immich.sh"

log "========================================"
log "FIN DE LA SAUVEGARDE"
log "========================================"

exit 0
