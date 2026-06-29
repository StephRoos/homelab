#!/bin/bash
# ============================================================================
# Setup Cloudflare Tunnel for Immich
# ============================================================================

set -euo pipefail

TUNNEL_NAME="${1:-homelab-immich}"
DOMAIN="photos.stephaneroos.com"
WEB_PORT="2284"
API_PORT="2283"

echo "=========================================="
echo "CLOUDFLARE TUNNEL - IMMICH"
echo "=========================================="
echo ""

# Vérifier si cloudflared est installé
if ! command -v cloudflared &> /dev/null; then
    echo "❌ cloudflared n'est pas installé"
    echo "Installer avec :"
    echo "  wget -q https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64"
    echo "  chmod +x cloudflared-linux-amd64"
    echo "  sudo mv cloudflared-linux-amd64 /usr/local/bin/cloudflared"
    exit 1
fi

echo "✓ cloudflared installé"
echo ""

# Instructions pour créer le tunnel
echo "1. Aller sur https://dash.cloudflare.com/ → Zero Trust → Access → Tunnels"
echo "2. Cliquer sur 'Create a tunnel'"
echo "3. Nommer le tunnel: '$TUNNEL_NAME'"
echo "4. Après création, copier le Tunnel ID"
echo ""

read -p "Entrer le Tunnel ID (ou appuyer sur Entrée pour utiliser cloudflared login): " tunnel_id

if [ -z "$tunnel_id" ]; then
    echo ""
    echo "Utilisation de cloudflared login..."
    echo "1. Une URL va s'afficher"
    echo "2. Ouvrir l'URL dans un navigateur"
    echo "3. Autoriser l'accès"
    echo ""
    cloudflared tunnel login
    echo ""
    echo "✓ Certificat installé"
    echo ""
    read -p "Entrer le Tunnel ID maintenant: " tunnel_id
fi

if [ -z "$tunnel_id" ]; then
    echo "❌ Tunnel ID requis"
    exit 1
fi

# Créer la configuration
CONFIG_DIR="$HOME/.cloudflared"
mkdir -p "$CONFIG_DIR"

cat > "$CONFIG_DIR/immich.yml" << EOF
tunnel: $tunnel_id
credentials-file: $CONFIG_DIR/$tunnel_id.json

ingress:
  - hostname: $DOMAIN
    service: http://localhost:$WEB_PORT
  - hostname: api.$DOMAIN
    service: http://localhost:$API_PORT
  - service: http_status:404
EOF

echo "✓ Configuration créée: $CONFIG_DIR/immich.yml"
echo ""

# Créer le service systemd
SERVICE_FILE="/tmp/cloudflared-immich.service"

cat > "$SERVICE_FILE" << EOF
[Unit]
Description=Cloudflare Tunnel for Immich
After=network.target
Wants=network-online.target

[Service]
Type=simple
User=steph
Group=steph
ExecStart=/usr/local/bin/cloudflared tunnel --config $CONFIG_DIR/immich.yml run
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

sudo cp "$SERVICE_FILE" /etc/systemd/system/cloudflared-immich.service
sudo systemctl daemon-reload

echo "✓ Service systemd créé"
echo ""

# Démarrer le service
echo "Démarrage du tunnel..."
sudo systemctl enable cloudflared-immich
sudo systemctl start cloudflared-immich

sleep 3

if sudo systemctl is-active --quiet cloudflared-immich; then
    echo ""
    echo "=========================================="
    echo "✓ TUNNEL ACTIF"
    echo "=========================================="
    echo ""
    echo "Immich devrait être accessible sur:"
    echo "  → https://$DOMAIN"
    echo ""
    echo "Pour voir les logs:"
    echo "  sudo journalctl -u cloudflared-immich -f"
    echo ""
else
    echo "❌ Erreur lors du démarrage"
    sudo journalctl -u cloudflared-immich -n 20 --no-pager
    exit 1
fi
