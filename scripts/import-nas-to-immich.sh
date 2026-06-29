#!/bin/bash
# ============================================================================
# Script: import-nas-to-immich.sh
# Description: Import des photos depuis le NAS vers Immich
# Auteur: Homelab
# Date: 25 juin 2026
# ============================================================================
#
# Ce script importe les photos depuis un dossier du NAS vers Immich
# en utilisant immich-go pour la préservation des albums et métadonnées.
#
# Utilisation:
#   ./scripts/import-nas-to-immich.sh /mnt/nas/photos
#
# ============================================================================

set -euo pipefail

# ============================================================================
# CONFIGURATION
# ============================================================================

# Dossier source sur le NAS (à adapter)
SOURCE_DIR="${1:-/mnt/nas/photos}"

# URL Immich
IMMICH_URL="https://photos.stephaneroos.com"

# Dossier pour les logs
LOG_DIR="/var/log/immich"
LOG_FILE="$LOG_DIR/import-nas-$(date +%Y%m%d_%H%M%S).log"

# Fichiers à inclure
FILE_EXTENSIONS=("*.jpg" "*.jpeg" "*.png" "*.gif" "*.heic" "*.heif" "*.webp" "*.mp4" "*.mov" "*.avi" "*.mkv")

# ============================================================================
# COULEURS
# ============================================================================

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

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

# Vérifier que le script est exécuté sur le serveur
check_server() {
    if [ ! -d "/home/steph/homelab" ]; then
        log_error "Ce script doit être exécuté sur homelab (UM880 Plus)"
        echo "Utilise: ssh homelab"
        exit 1
    fi
}

# Vérifier immich-go est installé
check_immich_go() {
    if ! command -v immich-go &> /dev/null; then
        log_warn "immich-go n'est pas installé. Installation..."

        wget -q https://github.com/simulot/immich-go/releases/latest/download/immich-go-linux-amd64 -O /tmp/immich-go
        chmod +x /tmp/immich-go
        sudo mv /tmp/immich-go /usr/local/bin/immich-go

        if [ $? -eq 0 ]; then
            log_info "✓ immich-go installé"
        else
            log_error "Échec de l'installation d'immich-go"
            exit 1
        fi
    else
        log_info "✓ immich-go est déjà installé"
    fi
}

# Vérifier la clé API Immich
check_api_key() {
    if [ ! -f ~/.immich-go.yaml ]; then
        log_error "Configuration immich-go introuvable: ~/.immich-go.yaml"
        echo ""
        echo "Créer le fichier avec:"
        echo "  cat > ~/.immich-go.yaml << EOF"
        echo "  Server: \"$IMMICH_URL\""
        echo "  ApiKey: \"TA_CLÉ_API_À_RÉCUPÉRER_DANS_IMMICH\""
        echo "  EOF"
        echo ""
        echo "Pour obtenir la clé API:"
        echo "  1. Aller sur $IMMICH_URL"
        echo "  2. Avatar → Paramètres d'administration"
        echo "  3. Scroller jusqu'à 'API Keys'"
        echo "  4. Créer une nouvelle clé (permissions: Read+Upload assets, Create albums)"
        exit 1
    fi
    log_info "✓ Configuration immich-go trouvée"
}

# Compter les fichiers source
count_source_files() {
    log_step "Comptage des fichiers dans $SOURCE_DIR"

    local total=0
    local detail=""

    for ext in jpg jpeg png gif heic heif webp mp4 mov avi mkv; do
        local count=$(find "$SOURCE_DIR" -type f -iname "*.$ext" 2>/dev/null | wc -l)
        if [ "$count" -gt 0 ]; then
            detail="$detail\n  - .$ext : $count"
            total=$((total + count))
        fi
    done

    echo -e "$detail" | tee -a "$LOG_FILE"
    log_info "📊 Total estimé: $total fichiers"

    echo "$total"
}

# Vérifier l'espace disque
check_disk_space() {
    log_step "Vérification de l'espace disque"

    local available_gb=$(df -h /mnt/nas 2>/dev/null | awk 'NR==2 {print $4}' | tr -d 'G')
    local available_mb=$(df -m /mnt/nas 2>/dev/null | awk 'NR==2 {print $4}')

    log_info "Espace disponible sur /mnt/nas: ${available_gb}GB (${available_mb}MB)"

    if [ "${available_mb:-0}" -lt 10240 ]; then
        log_warn "⚠️  Espace disque faible (< 10GB)"
    fi
}

# Lancer l'import
run_import() {
    log_step "Import avec immich-go"

    log_info "Source: $SOURCE_DIR"
    log_info "Destination: Immich ($IMMICH_URL)"
    log_info "Options: --recursive --albums --delete-after-import"

    # Lancer immich-go
    immich-go import \
        --recursive \
        --albums \
        --delete-after-import \
        --verbose \
        "$SOURCE_DIR" 2>&1 | tee -a "$LOG_FILE"

    local exit_code=${PIPESTATUS[0]}

    if [ $exit_code -eq 0 ]; then
        log_info "✓ Import terminé avec succès"
    else
        log_error "Erreur lors de l'import (code: $exit_code)"
        return $exit_code
    fi
}

# Vérifier l'import
verify_import() {
    log_step "Vérification de l'import"

    # Compter les fichiers importés via API (si disponible)
    # Sinon, demander de vérifier manuellement

    log_info "Pour vérifier le nombre de photos dans Immich:"
    echo ""
    echo "  1. Aller sur $IMMICH_URL"
    echo "  2. Cliquer sur l'avatar → Paramètres d'administration"
    echo "  3. Regarder dans 'Statistiques du serveur'"
    echo ""
    echo "Ou via l'API:"
    echo "  curl -H \"Authorization: Bearer TA_CLÉ\" \\"
    echo "    $IMMICH_URL/api/assets/statistics"
}

# ============================================================================
# MAIN
# ============================================================================

main() {
    # Créer le dossier de logs
    mkdir -p "$LOG_DIR"

    echo "========================================"
    echo "IMPORT NAS → IMMICH"
    echo "========================================"
    echo ""
    echo "Source: $SOURCE_DIR"
    echo "Destination: $IMMICH_URL"
    echo "Log: $LOG_FILE"
    echo ""

    # Vérifications
    check_server
    check_immich_go
    check_api_key

    # Vérifier que le dossier source existe
    if [ ! -d "$SOURCE_DIR" ]; then
        log_error "Dossier source introuvable: $SOURCE_DIR"
        exit 1
    fi

    # Compter les fichiers
    SOURCE_COUNT=$(count_source_files)

    if [ "$SOURCE_COUNT" -eq 0 ]; then
        log_error "Aucun fichier trouvé dans $SOURCE_DIR"
        exit 1
    fi

    # Vérifier l'espace
    check_disk_space

    # Confirmation
    echo ""
    read -p "Continuer l'import de $SOURCE_COUNT fichiers ? (o/n) : " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[OoYy]$ ]]; then
        log_warn "Import annulé"
        exit 0
    fi

    # Import
    run_import
    IMPORT_STATUS=$?

    # Vérification
    verify_import

    # Résumé
    echo ""
    echo "========================================"
    echo "IMPORT TERMINÉ"
    echo "========================================"
    echo ""
    echo "Log: $LOG_FILE"
    echo ""

    if [ $IMPORT_STATUS -eq 0 ]; then
        log_info "✓ Import réussi !"
        log_info "Prochaine étape: Comparer avec Google Photos"
    else
        log_error "⚠️  Import terminé avec des erreurs"
        log_error "Vérifier le log: $LOG_FILE"
    fi

    return $IMPORT_STATUS
}

# Exécuter
main
exit $?
