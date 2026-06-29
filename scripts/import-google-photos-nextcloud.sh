#!/bin/bash
# ============================================================================
# Import Google Photos vers Nextcloud
# ============================================================================
#
# Workflow:
# 1. Google Takeout (Photos only, Original quality)
# 2. Télécharger les .zip sur le Mac
# 3. Transférer vers /mnt/nas/temp/google-takeout
# 4. Ce script extrait et organise pour Nextcloud
# 5. Import manuel dans Nextcloud (ou via occ)
#
# ============================================================================

set -euo pipefail

# ============================================================================
# CONFIGURATION
# ============================================================================

TAKEOUT_DIR="${1:-/mnt/nas/temp/google-takeout}"
NEXTCLOUD_DATA_DIR="/mnt/nas/nextcloud/data/steph/files/Photos"
NEXTCLOUD_USER="steph"
TEMP_DIR="/tmp/google-photos-import-$$"
LOG_FILE="/var/log/google-photos-nextcloud-$(date +%Y%m%d_%H%M%S).log"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# ============================================================================
# FUNCTIONS
# ============================================================================

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1" | tee -a "$LOG_FILE"
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1" | tee -a "$LOG_FILE"
}

info() {
    echo -e "${YELLOW}[INFO]${NC} $1" | tee -a "$LOG_FILE"
}

check_requirements() {
    log "Vérification des prérequis..."

    local missing=()

    command -v unzip >/dev/null 2>&1 || missing+=("unzip")
    command -v jq >/dev/null 2>&1 || missing+=("jq")

    if [ ${#missing[@]} -gt 0 ]; then
        error "Commandes manquantes: ${missing[*]}"
        info "Installer avec: sudo apt install ${missing[*]}"
        exit 1
    fi

    if [ ! -d "$TAKEOUT_DIR" ]; then
        error "Dossier Takeout introuvable: $TAKEOUT_DIR"
        info "Instructions:"
        info "1. Aller sur https://takeout.google.com"
        info "2. Sélectionner 'Photos only'"
        info "3. Choisir 'Original quality'"
        info "4. Télécharger et placer les .zip dans: $TAKEOUT_DIR"
        exit 1
    fi

    success "Prérequis OK"
}

extract_takeout() {
    log "Extraction des archives Google Takeout..."

    mkdir -p "$TEMP_DIR/extracted"

    # Find all zip files
    local zip_files=()
    while IFS= read -r -d '' file; do
        zip_files+=("$file")
    done < <(find "$TAKEOUT_DIR" -type f \( -name "*.zip" -o -name "*.tgz" \) -print0)

    if [ ${#zip_files[@]} -eq 0 ]; then
        error "Aucun fichier .zip ou .tgz trouvé dans $TAKEOUT_DIR"
        exit 1
    fi

    info "${#zip_files[@]} archives trouvées"

    # Extract each archive
    for i in "${!zip_files[@]}"; do
        local zip="${zip_files[$i]}"
        info "[$((i+1))/${#zip_files[@]}] Extraction: $(basename "$zip")"

        if [[ "$zip" == *.zip ]]; then
            unzip -q -o "$zip" -d "$TEMP_DIR/extracted/"
        elif [[ "$zip" == *.tgz ]]; then
            tar -xzf "$zip" -C "$TEMP_DIR/extracted/"
        fi
    done

    success "Extraction terminée"
}

organize_photos() {
    log "Organisation des photos par année..."

    mkdir -p "$TEMP_DIR/organized"

    # Google Takeout structure varies, find all photos
    local photo_count=0

    # Common photo extensions
    while IFS= read -r -d '' file; do
        photo_count=$((photo_count + 1))

        # Get file modification date or try EXIF
        local year
        year=$(date -r "$file" "+%Y" 2>/dev/null || echo "unknown")

        # Create year directory
        mkdir -p "$TEMP_DIR/organized/$year"

        # Copy with original filename (Google renames, so we preserve original)
        local basename
        basename=$(basename "$file")
        cp "$file" "$TEMP_DIR/organized/$year/$basename"

    done < <(find "$TEMP_DIR/extracted" -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.heic" -o -iname "*.webp" -o -iname "*.mp4" -o -iname "*.mov" -o -iname "*.gif" \) -print0)

    success "$photo_count photos/vidéos organisées par année"

    # Show summary by year
    info "Répartition par année:"
    find "$TEMP_DIR/organized" -type d -mindepth 1 -maxdepth 1 -exec sh -c 'echo "{}: $(find "{}" -type f | wc -l) fichiers"' \;
}

copy_to_nextcloud() {
    log "Copie vers Nextcloud..."

    # Ensure Nextcloud directory exists
    if [ ! -d "$NEXTCLOUD_DATA_DIR" ]; then
        info "Création du dossier Photos Nextcloud..."
        mkdir -p "$NEXTCLOUD_DATA_DIR"
        chown -R www-data:www-data "$NEXTCLOUD_DATA_DIR"
    fi

    # Copy organized photos
    info "Copie des photos vers $NEXTCLOUD_DATA_DIR/Google Photos..."
    cp -r "$TEMP_DIR/organized" "$NEXTCLOUD_DATA_DIR/Google Photos"

    # Fix permissions
    chown -R www-data:www-data "$NEXTCLOUD_DATA_DIR/Google Photos"

    success "Photos copiées vers Nextcloud"
}

trigger_nextcloud_scan() {
    log "Scan des fichiers dans Nextcloud..."

    docker exec nextcloud-aio-nextcloud php occ files:scan --path="/steph/files/Photos" 2>&1 | tee -a "$LOG_FILE"

    success "Scan terminé - Les photos devraient apparaître dans l'app Photos"
}

show_summary() {
    log ""
    log "=========================================="
    log "RÉSUMÉ DE L'IMPORT"
    log "=========================================="
    log ""
    log "Photos importées dans: $NEXTCLOUD_DATA_DIR/Google Photos"
    log ""
    log "Pour voir les photos:"
    log "1. Aller sur https://cloud.anthemion.dev/apps/photos"
    log "2. Naviguer vers 'Photos' > 'Google Photos'"
    log ""
    log "Log complet: $LOG_FILE"
    log ""
    log "Temp directory (à nettoyer): $TEMP_DIR"
    log ""
}

# ============================================================================
# MAIN
# ============================================================================

main() {
    log "=== DÉBUT IMPORT GOOGLE PHOTOS VERS NEXTCLOUD ==="

    check_requirements
    extract_takeout
    organize_photos
    copy_to_nextcloud
    trigger_nextcloud_scan
    show_summary

    # Keep temp dir for inspection
    info "Dossier temporaire conservé: $TEMP_DIR"
    info "Pour nettoyer: rm -rf $TEMP_DIR"

    log "=== IMPORT TERMINÉ ==="
}

# Run
main "$@"
