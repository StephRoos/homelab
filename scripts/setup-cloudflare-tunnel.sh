#!/bin/bash
# ============================================================================
# Script: setup-cloudflare-tunnel.sh
# Description: Configure Cloudflare Tunnel pour Immich
# Date: 25 juin 2026
# ============================================================================

set -euo pipefail

# ============================================================================
# CONFIGURATION
# ============================================================================

TUNNEL_NAME="homelab-immich"
DOMAIN="photos.stephaneroos.com"
CONFIG_FILE="/home/steph/homelab/configs/docker/cloudflared-immich.yml"
SERVICE_FILE="/home/steph/homelab/configs/system/cloudflared-immich.service"
CLOUDFLARED_DIR="/home/steph/.cloudflared"

# Couleurs
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_step() {
    echo -e "\n${BLUE}[ÉTAPE]${NC} $1"
}

# ============================================================================
# PRÉREQUIS
# ============================================================================

check_prereqs() {
    log_step "Vérification des prérequis"

    # Vérifier cloudflared installé
    if ! command -v cloudflared &> /dev/null; then
        log_error "cloudflared n'est pas installé"
        log_info "Installer avec: wget -q https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64 && chmod +x cloudflared-linux-amd64 && sudo mv cloudflared-linux-amd64 /usr/local/bin/cloudflared"
        exit 1
    fi
    log_info "✓ cloudflared installé"

    # Vérifier que Immich est accessible
    if ! curl -s -o /dev/null -w "%{http_code}" http://localhost:2284/ | grep -q "200\|302"; then
        log_warn "Immich ne répond pas sur http://localhost:2284/"
        log_warn "Assurez-vous que Immich est démarré"
    else
        log_info "✓ Immich accessible"
    fi
}

# ============================================================================
# DEMANDE DU CERTIFICAT
# ============================================================================

setup_cert() {
    log_step "Configuration du certificat Cloudflare"

    mkdir -p "$CLOUDFLARED_DIR"

    if [ -f "$CLOUDFLARED_DIR/cert.pem" ]; then
        log_info "Certificat existant trouvé"
        read -p "Utiliser le certificat existant ? (o/n) : " -n 1 -r
        echo
        if [[ $REPLY =~ ^[OoYy]$ ]]; then
            log_info "Utilisation du certificat existant"
            return
        fi
    fi

    cat << 'EOF'

    1. Aller sur https://dash.cloudflare.com/ -> Zero Trust -> Access -> Tunnels
    2. Cliquer sur "Create a tunnel"
    3. Donner un nom (ex: homelab-immich)
    4. Choisir "Debian/Ubuntu" ou "Generic Linux"
    5. Copier le tunnel_id affiché

EOF

    read -p "Entrer le TUNNEL_ID: " tunnel_id

    if [ -z "$tunnel_id" ]; then
        log_error "TUNNEL_ID requis"
        exit 1
    fi

    # Télécharger le certificat via le tunnel token
    log_info "Téléchargement du certificat..."
    cloudflared tunnel token "$tunnel_id" > "$CLOUDFLARED_DIR/${tunnel_id}.json" 2>&1 || true

    if [ -f "$CLOUDFLARED_DIR/${tunnel_id}.json" ]; then
        log_info "✓ Certificat téléchargé"
    else
        log_warn "Impossible de télécharger automatiquement"
        log_info "Créer le fichier $CLOUDFLARED_DIR/${tunnel_id}.json avec le contenu depuis Cloudflare"
    fi

    # Mettre à jour la config
    sed -i "s/<TUNNEL_ID>/$tunnel_id/g" "$CONFIG_FILE"
}

# ============================================================================
# CONFIGURATION
# ============================================================================

setup_config() {
    log_step "Configuration du tunnel"

    # Copier le service systemd
    sudo cp "$SERVICE_FILE" /etc/systemd/system/cloudflared-immich.service

    # Recharger systemd
    sudo systemctl daemon-reload

    log_info "✓ Configuration terminée"
}

# ============================================================================
# DÉMARRAGE
# ============================================================================

start_tunnel() {
    log_step "Démarrage du tunnel"

    sudo systemctl enable cloudflared-immich
    sudo systemctl start cloudflared-immich

    sleep 3

    if sudo systemctl is-active --quiet cloudflared-immich; then
        log_info "✓ Tunnel actif"
    else
        log_error "Erreur lors du démarrage"
        sudo systemctl status cloudflared-immich
        exit 1
    fi
}

# ============================================================================
# VÉRIFICATION
# ============================================================================

verify() {
    log_step "Vérification"

    echo ""
    log_info "Le tunnel devrait être accessible sur: https://$DOMAIN"
    echo ""
    log_info "Pour vérifier les logs:"
    echo "  sudo journalctl -u cloudflared-immich -f"
    echo ""
    log_info "Pour redémarrer:"
    echo "  sudo systemctl restart cloudflared-immich"
    echo ""
}

# ============================================================================
# MAIN
# ============================================================================

main() {
    echo "========================================"
    echo "SETUP CLOUDFLARE TUNNEL POUR IMMICH"
    echo "========================================"
    echo ""

    check_prereqs
    setup_cert
    setup_config
    start_tunnel
    verify
}

main "$@"
