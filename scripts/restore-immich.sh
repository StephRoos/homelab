#!/bin/bash
# Script: restore-immich.sh
# Description: Restauration de la configuration Immich depuis une sauvegarde
# Auteur: Mistral Vibe
# Date: 25 juin 2026
# Environnement: À exécuter sur homelab (UM880 Plus)

set -euo pipefail

# ============================================================================
# CONFIGURATION
# ============================================================================

# Répertoire de sauvegarde
BACKUP_DIR="/mnt/nas/backups/immich"

# Date pour la restauration (laisser vide pour la dernière sauvegarde)
# Exemple: DATE="20260625_120000"
DATE="${1:-}"

# Fichier de log
LOG_FILE="/var/log/immich-restore-$(date +%Y%m%d_%H%M%S).log"

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
# VÉRIFICATIONS PRÉ-RESTAURATION
# ============================================================================

log "========================================"
log "DEBUT DE LA RESTAURATION IMMICH"
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

# Vérifier le répertoire de sauvegarde
if [ ! -d "$BACKUP_DIR" ]; then
    error "Répertoire de sauvegarde introuvable : $BACKUP_DIR"
    exit 1
fi

# Trouver la dernière sauvegarde si DATE n'est pas spécifié
if [ -z "$DATE" ]; then
    # Trouver la sauvegarde DB la plus récente
    LATEST_DB=$(ls -t "$BACKUP_DIR"/immich-db-*.sql 2>/dev/null | head -1 || true)
    if [ -z "$LATEST_DB" ]; then
        error "Aucune sauvegarde trouvée dans $BACKUP_DIR"
        exit 1
    fi
    DATE=$(basename "$LATEST_DB" | sed 's/immich-db-//;s/\.sql$//')
    log "Utilisation de la dernière sauvegarde : $DATE"
fi

log "Date de restauration : $DATE"

# ============================================================================
# ARRÊT DES CONTENEURS
# ============================================================================

log ""
log "=== ARRÊT DES CONTENEURS IMMICH ==="

# Se placer dans le bon répertoire
cd /home/steph/homelab/configs/docker

# Arrêter tous les conteneurs Immich
log "Arrêt des conteneurs..."
docker compose -f immich.yml down 2>&1 | tee -a "$LOG_FILE"

log "✅ Conteneurs arrêtés"

# ============================================================================
# RESTAURATION DE LA BASE DE DONNÉES
# ============================================================================

log ""
log "=== RESTAURATION DE LA BASE DE DONNÉES ==="

DB_BACKUP_FILE="$BACKUP_DIR/immich-db-$DATE.sql"

if [ ! -f "$DB_BACKUP_FILE" ]; then
    error "Fichier de sauvegarde DB introuvable : $DB_BACKUP_FILE"
    exit 1
fi

log "Fichier source : $DB_BACKUP_FILE"

# Supprimer l'ancien volume de données
log "Suppression de l'ancien volume PostgreSQL..."
docker volume rm -f immich-postgres-data 2>/dev/null || true

# Redémarrer PostgreSQL
log "Redémarrage de PostgreSQL..."
docker compose -f immich.yml up -d immich-postgres 2>&1 | tee -a "$LOG_FILE"

# Attendre que PostgreSQL soit prêt
log "Attente de la disponibilité de PostgreSQL..."
for i in {1..30}; do
    if docker exec immich-postgres pg_isready -U immich -d immich 2>/dev/null; then
        log "✅ PostgreSQL est prêt"
        break
    fi
    log "  Essai $i/30..."
    sleep 5
done

# Restaurer la base de données
log "Restauration de la base de données..."
cat "$DB_BACKUP_FILE" | docker exec -i immich-postgres psql -U immich -d immich 2>>"$LOG_FILE"

log "✅ Base de données restaurée"

# ============================================================================
# RESTAURATION DE LA CONFIGURATION
# ============================================================================

log ""
log "=== RESTAURATION DE LA CONFIGURATION ==="

CONFIG_BACKUP_FILE="$BACKUP_DIR/immich-config-$DATE.tar.gz"

if [ ! -f "$CONFIG_BACKUP_FILE" ]; then
    error "Fichier de sauvegarde config introuvable : $CONFIG_BACKUP_FILE"
    exit 1
fi

log "Fichier source : $CONFIG_BACKUP_FILE"

# Supprimer l'ancienne configuration
log "Suppression de l'ancienne configuration..."
rm -rf /mnt/nas/immich/config

# Extraire la configuration
log "Extraction de la configuration..."
tar -xzvf "$CONFIG_BACKUP_FILE" -C / 2>&1 | tee -a "$LOG_FILE"

log "✅ Configuration restaurée"

# ============================================================================
# RESTAURATION DES VOLUMES DOCKER
# ============================================================================

log ""
log "=== RESTAURATION DES VOLUMES DOCKER ==="

VOLUME_BACKUP_DIR="$BACKUP_DIR/volumes-$DATE"

if [ -d "$VOLUME_BACKUP_DIR" ]; then
    # Restaurer immich-postgres-data
    POSTGRES_VOLUME_BACKUP="$VOLUME_BACKUP_DIR/immich-postgres-data-$DATE.tar.gz"
    if [ -f "$POSTGRES_VOLUME_BACKUP" ]; then
        log "Restauration du volume PostgreSQL..."
        docker run --rm \
            -v immich-postgres-data:/var/lib/postgresql/data \
            -v "$VOLUME_BACKUP_DIR:/backup" \
            alpine \
            sh -c "rm -rf /var/lib/postgresql/data/* && \
                   cd /var/lib/postgresql/data && \
                   tar -xzvf /backup/immich-postgres-data-$DATE.tar.gz ." \
            >> "$LOG_FILE" 2>&1
        log "✅ Volume PostgreSQL restauré"
    fi

    # Restaurer immich-redis-data
    REDIS_VOLUME_BACKUP="$VOLUME_BACKUP_DIR/immich-redis-data-$DATE.tar.gz"
    if [ -f "$REDIS_VOLUME_BACKUP" ]; then
        log "Restauration du volume Redis..."
        docker run --rm \
            -v immich-redis-data:/data \
            -v "$VOLUME_BACKUP_DIR:/backup" \
            alpine \
            sh -c "rm -rf /data/* && \
                   cd /data && \
                   tar -xzvf /backup/immich-redis-data-$DATE.tar.gz ." \
            >> "$LOG_FILE" 2>&1
        log "✅ Volume Redis restauré"
    fi
else
    log "⚠️  Aucun volume sauvegardé trouvé, création de nouveaux volumes"
fi

# ============================================================================
# REDÉMARRAGE COMPLET
# ============================================================================

log ""
log "=== REDÉMARRAGE DES CONTENEURS ==="

# Redémarrer tous les conteneurs
log "Redémarrage de tous les conteneurs Immich..."
docker compose -f immich.yml --env-file .env up -d 2>&1 | tee -a "$LOG_FILE"

# Attendre que tous les conteneurs soient prêts
log "Attente de la disponibilité des services..."
for i in {1..60}; do
    HEALTHY_COUNT=$(docker ps | grep -c healthy || true)
    if [ "$HEALTHY_COUNT" -ge 3 ]; then
        log "✅ Tous les services sont opérationnels"
        break
    fi
    log "  Essai $i/60..."
    sleep 10
done

# ============================================================================
# VÉRIFICATION
# ============================================================================

log ""
log "=== VÉRIFICATION DE LA RESTAURATION ==="

# Vérifier les conteneurs
log "État des conteneurs :"
docker ps | grep immich || true

# Vérifier le server
log "Vérification du server..."
docker logs immich-server | grep "listening on" || true

# Tester l'accès
log "Test d'accès local..."
if curl -I http://localhost:2284 > /dev/null 2>&1; then
    log "✅ Accès local fonctionnel"
else
    log "⚠️  Accès local non disponible (peut prendre quelques minutes)"
fi

# ============================================================================
# CONFIRMATION
# ============================================================================

log ""
log "=== CONFIRMATION ==="

log ""
log "✅ RESTAURATION TERMINÉE"
log ""
log "Immich devrait être de nouveau opérationnel."
log ""
log "Vérifiez l'accès via :"
log "  - Local : http://localhost:2284"
log "  - Externe : https://photos.stephaneroos.com"
log ""
log "Fichier de log : $LOG_FILE"

log "========================================"
log "FIN DE LA RESTAURATION"
log "========================================"

exit 0
