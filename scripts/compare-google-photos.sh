#!/bin/bash
# ============================================================================
# Script: compare-google-photos.sh
# Description: Compare les photos Immich avec Google Photos
# Auteur: Homelab
# Date: 25 juin 2026
# ============================================================================
#
# Ce script compare les photos importées dans Immich avec celles qui sont
# encore sur Google Photos pour identifier les manquantes.
#
# Méthodes:
# 1. Par comptage (approximatif)
# 2. Par nom de fichier (plus précis)
# 3. Via Google Photos API (requiert un token)
#
# ============================================================================

set -euo pipefail

# ============================================================================
# CONFIGURATION
# ============================================================================

# URL Immich
IMMICH_URL="https://photos.stephaneroos.com"

# Chemins
NAS_PHOTO_DIR="/mnt/nas/photos"
LOG_DIR="/var/log/immich"
LOG_FILE="$LOG_DIR/compare-google-$(date +%Y%m%d_%H%M%S).log"

# Fichier de sortie pour les manquantes
MISSING_FILE="$LOG_DIR/missing-photos-$(date +%Y%m%d).txt"

# ============================================================================
# COULEURS
# ============================================================================

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31M'
BLUE='\033[0;34m'
NC='\033[0;M'

# ============================================================================
# FONCTIONS
# ============================================================================

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1" | tee -a "$LOG_FILE"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1" | tee -a "$LOG_FILE"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1" | tee -a "$LOG_FILE"
}

log_step() {
    echo -e "\n${BLUE}[ÉTAPE]${NC} $1" | tee -a "$LOG_FILE"
}

# Vérifier le serveur
check_server() {
    if [ ! -d "/home/steph/homelab" ]; then
        log_error "Ce script doit être exécuté sur homelab (UM880 Plus)"
        exit 1
    fi
}

# ============================================================================
# MÉTHODE 1 : COMPARAISON PAR COMPTAGE (RAPIDE)
# ============================================================================

compare_by_count() {
    log_step "Méthode 1: Comparaison par comptage"

    # Compter sur le NAS
    log_info "Comptage des fichiers sur le NAS..."
    NAS_COUNT=$(find "$NAS_PHOTO_DIR" -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.heic" -o -iname "*.mp4" -o -iname "*.mov" \) 2>/dev/null | wc -l)
    log_info "Photos sur NAS: $NAS_COUNT"

    # Compter dans Immich (via API)
    log_info "Récupération du comptage Immich..."

    if [ -f ~/.immich-go.yaml ]; then
        # Essayer de récupérer la clé API depuis le config
        API_KEY=$(grep "ApiKey:" ~/.immich-go.yaml | cut -d'"' -f2 || grep "ApiKey:" ~/.immich-go.yaml | cut -d' ' -f3)

        if [ -n "$API_KEY" ]; then
            IMMICH_COUNT=$(curl -s -H "Authorization: Bearer $API_KEY" \
                "$IMMICH_URL/api/assets/statistics" 2>/dev/null | \
                jq -r '.total // 0' 2>/dev/null || echo "N/A")

            log_info "Photos dans Immich: $IMMICH_COUNT"

            if [ "$IMMICH_COUNT" != "N/A" ] && [ "$NAS_COUNT" != "N/A" ]; then
                local diff=$((NAS_COUNT - IMMICH_COUNT))
                if [ $diff -eq 0 ]; then
                    log_info "✓ Comptage identique !"
                elif [ $diff -gt 0 ]; then
                    log_warn "⚠️  $diff photos de moins dans Immich que sur le NAS"
                else
                    log_warn "⚠️  ${diff#-} photos de plus dans Immich que sur le NAS"
                fi
            fi
        fi
    fi

    # Demander le comptage Google Photos (manuel)
    echo ""
    log_info "Pour connaître le nombre de photos dans Google Photos:"
    echo "  1. Aller sur https://photos.google.com"
    echo "  2. Scroller jusqu'en bas (ou vérifier le stockage)"
    echo "  3. Regarder 'Éléments' en haut à gauche"
    echo ""
}

# ============================================================================
# MÉTHODE 2 : COMPARAISON PAR NOM DE FICHIER
# ============================================================================

compare_by_filename() {
    log_step "Méthode 2: Comparaison par nom de fichier"

    # Créer la liste des fichiers du NAS
    local nas_list="$LOG_DIR/nas-files-$(date +%Y%m%d).txt"
    local immich_list="$LOG_DIR/immich-files-$(date +%Y%m%d).txt"

    log_info "Génération de la liste des fichiers NAS..."
    find "$NAS_PHOTO_DIR" -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.heic" \) \
        -exec basename {} \; 2>/dev/null | sort > "$nas_list"

    local nas_files=$(cat "$nas_list" | wc -l)
    log_info "Fichiers uniques sur NAS: $nas_files"

    # Récupérer la liste des fichiers Immich via API
    log_info "Récupération de la liste des fichiers Immich..."

    if [ -f ~/.immich-go.yaml ]; then
        API_KEY=$(grep "ApiKey:" ~/.immich-go.yaml | cut -d'"' -f2 || grep "ApiKey:" ~/.immich-go.yaml | cut -d' ' -f3)

        if [ -n "$API_KEY" ]; then
            # Récupérer tous les assets (paginé)
            local page=1
            local has_more=true

            echo -n "" > "$immich_list"

            while $has_more; do
                log_info "Récupération page $page..."

                local assets=$(curl -s -H "Authorization: Bearer $API_KEY" \
                    "$IMMICH_URL/api/assets?skip=$((page-1)*1000&take=1000" 2>/dev/null)

                # Extraire les noms originaux
                echo "$assets" | jq -r '.[]?.originalFileName // empty' 2>/dev/null >> "$immich_list"

                # Vérifier s'il y a plus de résultats
                local count=$(echo "$assets" | jq 'length' 2>/dev/null || echo "0")
                if [ "$count" -lt 1000 ]; then
                    has_more=false
                else
                    page=$((page + 1))
                fi
            done

            sort "$immich_list" -o "$immich_list"
            local immich_files=$(cat "$immich_list" | wc -l)
            log_info "Fichiers dans Immich: $immich_files"

            # Comparer
            log_info "Comparaison des fichiers..."
            comm -23 "$nas_list" "$immich_list" > "$MISSING_FILE"

            local missing=$(cat "$MISSING_FILE" | wc -l)
            if [ $missing -eq 0 ]; then
                log_info "✓ Tous les fichiers du NAS sont dans Immich !"
            else
                log_warn "⚠️  $missing fichiers du NAS manquent dans Immich"
                log_info "Liste: $MISSING_FILE"

                # Afficher les 10 premiers
                echo ""
                log_info "10 premiers fichiers manquants:"
                head -10 "$MISSING_FILE" | tee -a "$LOG_FILE"
            fi
        fi
    fi
}

# ============================================================================
# MÉTHODE 3 : GOOGLE PHOTOS API (OPTIONNEL)
# ============================================================================

google_photos_api_info() {
    log_step "Méthode 3: Google Photos API (optionnel)"

    cat << 'EOF'
Pour une comparaison précise avec Google Photos via API:

1. Créer un projet Google Cloud:
   https://console.cloud.google.com/

2. Activer l'API Photos Library

3. Créer un token OAuth 2.0:
   https://developers.google.com/photos/library/guides/create-client

4. Utiliser le script google-photos-api.sh (à créer)

Cela permet de:
- Lister toutes les photos Google Photos
- Comparer avec Immich
- Identifier uniquement les manquantes
EOF
}

# ============================================================================
# MAIN
# ============================================================================

main() {
    mkdir -p "$LOG_DIR"

    echo "========================================"
    echo "COMPARAISON IMMICH vs GOOGLE PHOTOS"
    echo "========================================"
    echo ""
    echo "Log: $LOG_FILE"
    echo ""

    check_server

    # Menu
    echo "Choisir la méthode de comparaison:"
    echo "  1. Par comptage (rapide, approximatif)"
    echo "  2. Par nom de fichier (plus précis)"
    echo "  3. Info sur Google Photos API"
    echo "  4. Toutes les méthodes"
    echo ""
    read -p "Choix (1-4): " choice

    case $choice in
        1)
            compare_by_count
            ;;
        2)
            compare_by_filename
            ;;
        3)
            google_photos_api_info
            ;;
        4)
            compare_by_count
            compare_by_filename
            google_photos_api_info
            ;;
        *)
            log_error "Choix invalide"
            exit 1
            ;;
    esac

    echo ""
    echo "========================================"
    echo "COMPARAISON TERMINÉE"
    echo "========================================"
    echo ""
    echo "Log: $LOG_FILE"
    if [ -f "$MISSING_FILE" ]; then
        echo "Fichiers manquants: $MISSING_FILE"
    fi
}

main
