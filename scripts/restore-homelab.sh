#!/bin/bash

# ============================================================================
# Script de Restauration Homelab
# ============================================================================
# **Auteur** : Stéphane
# **Dernière mise à jour** : 24 juin 2026
# **Description** : Restaure une sauvegarde complète du homelab
# **Usage** : bash /Users/stephane/Projects/homelab/scripts/restore-homelab.sh [DATE]
#
#   Si DATE n'est pas spécifié, utilise la sauvegarde la plus récente.
#
# ============================================================================

set -e  # Arrêter le script en cas d'erreur

# Configuration
# ============================================================================

# Répertoire de sauvegarde principal (sur le NAS)
BACKUP_ROOT="/mnt/nas/backups/homelab"

# Fichier de log
LOG_FILE="/tmp/restore-homelab-$(date +%Y%m%d_%H%M%S).log"

# Fonction de logging
log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# ============================================================================
# Initialisation
# ============================================================================

# Vérifier les droits root
if [ "$EUID" -ne 0 ]; then
    echo "Ce script doit être exécuté en tant que root (sudo)."
    exit 1
fi

# Vérifier le paramètre DATE
if [ -z "$1" ]; then
    # Trouver la sauvegarde la plus récente
    LAST_BACKUP=$(ls -td "$BACKUP_ROOT"/20* | head -n 1)
    if [ -z "$LAST_BACKUP" ]; then
        echo "Aucune sauvegarde trouvée dans $BACKUP_ROOT"
        exit 1
    fi
    BACKUP_DIR="$LAST_BACKUP"
    log "Aucune date spécifiée. Utilisation de la sauvegarde la plus récente : $BACKUP_DIR"
else
    BACKUP_DIR="$BACKUP_ROOT/$1"
    if [ ! -d "$BACKUP_DIR" ]; then
        echo "La sauvegarde $BACKUP_DIR n'existe pas."
        echo "Sauvegardes disponibles :"
        ls -td "$BACKUP_ROOT"/20* | while read dir; do
            echo "  - $(basename "$dir")"
        done
        exit 1
    fi
    log "Utilisation de la sauvegarde spécifiée : $BACKUP_DIR"
fi

# Vérifier que le NAS est monté
if [ ! -d "$BACKUP_ROOT" ]; then
    log "ERREUR : Le répertoire de sauvegarde $BACKUP_ROOT n'existe pas."
    log "Vérifie que le NAS est monté correctement."
    exit 1
fi

log "Démarrage de la restauration depuis : $BACKUP_DIR"

# ============================================================================
# Menu de restauration
# ============================================================================

show_menu() {
    cat << EOF

=== MENU DE RESTAURATION HOMELAB ===

Sauvegarde sélectionnée : $(basename "$BACKUP_DIR")

Choisissez ce que vous voulez restaurer :

1) Tout restaurer (COMPLET - Attention : écrase tout !)
2) Configurations Docker uniquement
3) Configurations système uniquement
4) Données des services uniquement
5) Bases de données uniquement
6) Documentation uniquement
7) Afficher le contenu de la sauvegarde
8) Quitter

EOF
}

while true; do
    show_menu
    read -p "Votre choix (1-8) : " choice
    
    case $choice in
        1)
            restore_all
            break
            ;;
        2)
            restore_docker
            break
            ;;
        3)
            restore_system
            break
            ;;
        4)
            restore_services
            break
            ;;
        5)
            restore_databases
            break
            ;;
        6)
            restore_documentation
            break
            ;;
        7)
            show_backup_content
            ;;
        8)
            log "Restauration annulée."
            exit 0
            ;;
        *)
            echo "Choix invalide. Veuillez réessayer."
            ;;
    esac
done

# ============================================================================
# Fonction : Afficher le contenu de la sauvegarde
# ============================================================================

show_backup_content() {
    log "=== Contenu de la sauvegarde : $BACKUP_DIR ==="
    
    if [ -f "$BACKUP_DIR/RESUME-*.txt" ]; then
        cat "$BACKUP_DIR"/RESUME-*.txt
    else
        log "Aucun fichier de résumé trouvé."
        log "Structure des fichiers :"
        find "$BACKUP_DIR" -type f | head -n 20
    fi
    
    log ""
    log "Taille totale : $(du -sh "$BACKUP_DIR" | cut -f1)"
}

# ============================================================================
# Fonction : Tout restaurer
# ============================================================================

restore_all() {
    log "=== RESTAURATION COMPLÈTE ==="
    log "Cette opération va restaurer TOUT le homelab."
    log "Toutes les données actuelles seront ECRASÉES !"
    
    read -p "Êtes-vous SÛR de vouloir continuer ? (oui/non) : " confirm
    if [ "$confirm" != "oui" ]; then
        log "Restauration complète annulée."
        exit 0
    fi
    
    # Arrêter tous les services
    log "Arrêt des services Docker..."
    docker stop $(docker ps -aq) 2>> "$LOG_FILE" || true
    
    log "Arrêt des services système..."
    systemctl stop docker cloudflared nut-server fail2ban 2>> "$LOG_FILE" || true
    
    # Restaurer toutes les parties
    restore_system
    restore_docker
    restore_services
    restore_databases
    restore_documentation
    
    # Redémarrer les services
    log "Redémarrage des services système..."
    systemctl start docker 2>> "$LOG_FILE"
    systemctl start cloudflared 2>> "$LOG_FILE" || true
    systemctl start nut-server 2>> "$LOG_FILE" || true
    systemctl start fail2ban 2>> "$LOG_FILE" || true
    
    log "Redémarrage des conteneurs Docker..."
    docker start $(docker ps -aq) 2>> "$LOG_FILE" || true
    
    log "✓ Restauration complète terminée !"
    log "Veuillez vérifier manuellement que tout fonctionne correctement."
}

# ============================================================================
# Fonction : Restaurer les configurations Docker
# ============================================================================

restore_docker() {
    log "=== Restauration des configurations Docker ==="
    
    # Restaurer daemon.json
    if [ -f "$BACKUP_DIR/docker/daemon.json" ]; then
        log "Restauration de daemon.json..."
        cp "$BACKUP_DIR/docker/daemon.json" /etc/docker/daemon.json
        chmod 644 /etc/docker/daemon.json
        log "✓ daemon.json restauré"
    else
        log "⚠ daemon.json non trouvé dans la sauvegarde"
    fi
    
    # Redémarrer Docker pour appliquer les changements
    if [ -f "$BACKUP_DIR/docker/daemon.json" ]; then
        log "Redémarrage de Docker..."
        systemctl restart docker 2>> "$LOG_FILE"
        log "✓ Docker redémarré"
    fi
    
    # Restaurer les réseaux Docker
    if [ -d "$BACKUP_DIR/docker/networks" ]; then
        log "Restauration des réseaux Docker..."
        for network_file in "$BACKUP_DIR/docker/networks"/*.json; do
            network_name=$(basename "$network_file" | sed 's/-.*//')
            log "  Restauration du réseau $network_name..."
            # Supprimer le réseau existant s'il existe
            docker network rm "$network_name" 2>> "$LOG_FILE" || true
            # Créer le réseau depuis le fichier de sauvegarde
            # Note : La restauration complète des réseaux est complexe,
            # il est souvent plus simple de les recréer manuellement
            log "  ⚠ La restauration automatique des réseaux n'est pas implémentée."
            log "  Veuillez recréer les réseaux manuellement ou utiliser docker-compose."
        done
    fi
    
    # Restaurer les volumes Docker (métadonnées uniquement)
    # Note : Les données des volumes ne sont pas restaurées automatiquement
    # car elles pourraient contenir des données sensibles ou obsolètes
    if [ -d "$BACKUP_DIR/docker/volumes" ]; then
        log "⚠ Les données des volumes Docker ne sont pas restaurées automatiquement."
        log "Pour restaurer un volume spécifique, utilisez :"
        log "  docker run --rm -v <volume>:/volume -v <backup>:/backup alpine tar xvf /backup/<file>.tar -C /"
    fi
    
    log "✓ Configurations Docker restaurées"
}

# ============================================================================
# Fonction : Restaurer les configurations système
# ============================================================================

restore_system() {
    log "=== Restauration des configurations système ==="
    
    # Sauvegarder les configurations actuelles avant restauration
    BACKUP_CURRENT="$BACKUP_ROOT/restore-backup-$(date +%Y%m%d_%H%M%S)"
    mkdir -p "$BACKUP_CURRENT"
    log "Sauvegarde des configurations actuelles dans : $BACKUP_CURRENT"
    
    # Fichiers à restaurer
    declare -A SYSTEM_FILES=(
        ["/etc/netplan/00-installer-config.yaml"]="system/etc/netplan/00-installer-config.yaml"
        ["/etc/hosts"]="system/etc/hosts"
        ["/etc/fstab"]="system/etc/fstab"
        ["/etc/ufw/ufw.conf"]="system/etc/ufw/ufw.conf"
        ["/etc/fail2ban/jail.local"]="system/etc/fail2ban/jail.local"
        ["/etc/nut/ups.conf"]="system/etc/nut/ups.conf"
        ["/etc/nut/upsmon.conf"]="system/etc/nut/upsmon.conf"
    )
    
    # Restaurer chaque fichier
    for dest in "${!SYSTEM_FILES[@]}"; do
        src="$BACKUP_DIR/${SYSTEM_FILES[$dest]}"
        if [ -f "$src" ]; then
            # Sauvegarder le fichier actuel
            mkdir -p "$BACKUP_CURRENT/$(dirname "$dest")"
            if [ -f "$dest" ]; then
                cp "$dest" "$BACKUP_CURRENT/$(dirname "$dest")/"
            fi
            
            # Restaurer le fichier
            cp "$src" "$dest" 2>> "$LOG_FILE"
            chmod 644 "$dest" 2>> "$LOG_FILE"
            log "✓ $dest restauré"
        else
            log "⚠ $src non trouvé dans la sauvegarde"
        fi
    done
    
    # Restaurer SSH (sans écraser les clés privées)
    if [ -d "$BACKUP_DIR/system/ssh" ]; then
        log "Restauration des configurations SSH..."
        mkdir -p "$BACKUP_CURRENT/.ssh"
        
        # Sauvegarder les clés actuelles
        if [ -f "$HOME/.ssh/config" ]; then
            cp "$HOME/.ssh/config" "$BACKUP_CURRENT/.ssh/"
        fi
        if [ -f "$HOME/.ssh/authorized_keys" ]; then
            cp "$HOME/.ssh/authorized_keys" "$BACKUP_CURRENT/.ssh/"
        fi
        
        # Restaurer config et authorized_keys
        if [ -f "$BACKUP_DIR/system/ssh/config" ]; then
            cp "$BACKUP_DIR/system/ssh/config" "$HOME/.ssh/"
            chmod 600 "$HOME/.ssh/config"
            log "✓ ~/.ssh/config restauré"
        fi
        
        if [ -f "$BACKUP_DIR/system/ssh/authorized_keys" ]; then
            cp "$BACKUP_DIR/system/ssh/authorized_keys" "$HOME/.ssh/"
            chmod 600 "$HOME/.ssh/authorized_keys"
            chown "$USER:" "$HOME/.ssh/authorized_keys"
            log "✓ ~/.ssh/authorized_keys restauré"
        fi
    fi
    
    # Restaurer crontab
    if [ -f "$BACKUP_DIR/system/crontab-*.txt" ]; then
        log "Restauration de crontab..."
        crontab "$BACKUP_DIR/system/crontab-*.txt" 2>> "$LOG_FILE"
        log "✓ Crontab restauré"
    fi
    
    # Appliquer la configuration réseau
    if [ -f "/etc/netplan/00-installer-config.yaml" ]; then
        log "Application de la configuration réseau..."
        netplan apply 2>> "$LOG_FILE"
        log "✓ Configuration réseau appliquée"
    fi
    
    # Redémarrer les services système
    log "Redémarrage des services système..."
    systemctl restart fail2ban 2>> "$LOG_FILE" || true
    systemctl restart nut-server 2>> "$LOG_FILE" || true
    systemctl restart ufw 2>> "$LOG_FILE" || true
    
    log "✓ Configurations système restaurées"
}

# ============================================================================
# Fonction : Restaurer les données des services
# ============================================================================

restore_services() {
    log "=== Restauration des données des services ==="
    
    # Nextcloud
    if [ -d "$BACKUP_DIR/services/nextcloud" ]; then
        log "Restauration de Nextcloud..."
        
        # Arrêter le conteneur Nextcloud
        if docker ps -a --format '{{.Names}}' | grep -q "nextcloud-aio-mastercontainer"; then
            docker stop nextcloud-aio-mastercontainer 2>> "$LOG_FILE" || true
            log "  Conteneur Nextcloud arrêté"
        fi
        
        # Restaurer les données
        if [ -f "$BACKUP_DIR/services/nextcloud/nextcloud-data-*.tar.gz" ]; then
            LATEST_NEXTCLOUD=$(ls -t "$BACKUP_DIR/services/nextcloud"/nextcloud-data-*.tar.gz | head -n 1)
            log "  Extraction de $LATEST_NEXTCLOUD..."
            tar -xzf "$LATEST_NEXTCLOUD" -C / 2>> "$LOG_FILE"
            log "  ✓ Nextcloud restauré"
        fi
        
        # Redémarrer Nextcloud
        if docker ps -a --format '{{.Names}}' | grep -q "nextcloud-aio-mastercontainer"; then
            docker start nextcloud-aio-mastercontainer 2>> "$LOG_FILE" || true
            log "  Conteneur Nextcloud redémarré"
        fi
    fi
    
    # Coolify
    if [ -d "$BACKUP_DIR/services/coolify" ]; then
        log "Restauration de Coolify..."
        
        # Arrêter les conteneurs Coolify
        docker stop coolify coolify-db coolify-redis coolify-minio 2>> "$LOG_FILE" || true
        
        # Restaurer les données
        if [ -f "$BACKUP_DIR/services/coolify/coolify-data-*.tar.gz" ]; then
            LATEST_COOLIFY=$(ls -t "$BACKUP_DIR/services/coolify"/coolify-data-*.tar.gz | head -n 1)
            log "  Extraction de $LATEST_COOLIFY..."
            tar -xzf "$LATEST_COOLIFY" -C / 2>> "$LOG_FILE"
            
            # Corriger les permissions
            chown -R 1000:1000 /mnt/nas/appdata/coolify 2>> "$LOG_FILE" || true
            log "  ✓ Coolify restauré"
        fi
        
        # Redémarrer Coolify
        docker start coolify coolify-db coolify-redis coolify-minio 2>> "$LOG_FILE" || true
        log "  Conteneurs Coolify redémarrés"
    fi
    
    # Uptime Kuma
    if [ -d "$BACKUP_DIR/services/uptime-kuma" ]; then
        log "Restauration de Uptime Kuma..."
        
        # Arrêter le conteneur
        if docker ps -a --format '{{.Names}}' | grep -q "uptime-kuma"; then
            docker stop uptime-kuma 2>> "$LOG_FILE" || true
        fi
        
        # Restaurer les données
        if [ -f "$BACKUP_DIR/services/uptime-kuma/uptime-kuma-data-*.tar.gz" ]; then
            LATEST_UPTIME=$(ls -t "$BACKUP_DIR/services/uptime-kuma"/uptime-kuma-data-*.tar.gz | head -n 1)
            log "  Extraction de $LATEST_UPTIME..."
            tar -xzf "$LATEST_UPTIME" -C / 2>> "$LOG_FILE"
            log "  ✓ Uptime Kuma restauré"
        fi
        
        # Redémarrer
        if docker ps -a --format '{{.Names}}' | grep -q "uptime-kuma"; then
            docker start uptime-kuma 2>> "$LOG_FILE" || true
        fi
    fi
    
    log "✓ Données des services restaurées"
}

# ============================================================================
# Fonction : Restaurer les bases de données
# ============================================================================

restore_databases() {
    log "=== Restauration des bases de données ==="
    
    # Arrêter les conteneurs de base de données
    docker stop coolify-db 2>> "$LOG_FILE" || true
    
    # Restaurer coolify-db
    if [ -f "$BACKUP_DIR/databases/coolify-db-*.sql" ]; then
        LATEST_DB=$(ls -t "$BACKUP_DIR/databases"/coolify-db-*.sql | head -n 1)
        log "Restauration de coolify-db depuis $LATEST_DB..."
        
        # Redémarrer le conteneur
        docker start coolify-db 2>> "$LOG_FILE"
        
        # Attendre que PostgreSQL soit prêt
        log "Attente du démarrage de PostgreSQL..."
        sleep 10
        
        # Restaurer la base de données
        cat "$LATEST_DB" | docker exec -i coolify-db psql -U coolify -d coolify 2>> "$LOG_FILE"
        log "✓ Base de données coolify-db restaurée"
    fi
    
    log "✓ Bases de données restaurées"
}

# ============================================================================
# Fonction : Restaurer la documentation
# ============================================================================

restore_documentation() {
    log "=== Restauration de la documentation ==="
    
    if [ -d "$BACKUP_DIR/documentation" ]; then
        log "Restauration de la documentation..."
        cp -r "$BACKUP_DIR/documentation/." /Users/stephane/Projects/homelab/Documents/ 2>> "$LOG_FILE"
        log "✓ Documentation restaurée"
    else
        log "⚠ Documentation non trouvée dans la sauvegarde"
    fi
}

# ============================================================================
# Exécuter le menu
# ============================================================================

# Initialiser le log
echo "=== Début de la restauration - $(date +%Y%m%d_%H%M%S) ===" > "$LOG_FILE"
echo "" >> "$LOG_FILE"
log "Script de restauration Homelab"
log "Sauvegarde sélectionnée : $BACKUP_DIR"
log "Fichier de log : $LOG_FILE"

# Démarrer le menu
show_menu
