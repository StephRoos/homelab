#!/bin/bash

# ============================================================================
# Script de Sauvegarde Homelab
# ============================================================================
# **Auteur** : Stéphane
# **Dernière mise à jour** : 24 juin 2026
# **Description** : Sauvegarde complète du homelab (Docker, système, configs)
# **Usage** : bash /Users/stephane/Projects/homelab/scripts/backup-homelab.sh
#
# ============================================================================

# Configuration
# ============================================================================

# Répertoire de sauvegarde principal (sur le NAS)
BACKUP_ROOT="/mnt/nas/backups/homelab"

# Date et heure pour le nom des sauvegardes
DATE=$(date +%Y%m%d_%H%M%S)
DAY=$(date +%Y%m%d)

# Répertoire de sauvegarde pour cette exécution
BACKUP_DIR="$BACKUP_ROOT/$DATE"

# Fichier de log
LOG_FILE="$BACKUP_ROOT/backup-$DATE.log"

# Nombre de jours de rétention
RETENTION_DAYS=30

# ============================================================================
# Initialisation
# ============================================================================

# Créer les répertoires
mkdir -p "$BACKUP_DIR"

# Initialiser le log
echo "=== Début de la sauvegarde - $DATE ===" | tee -a "$LOG_FILE"
echo "" | tee -a "$LOG_FILE"

# Fonction de logging
log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# Vérifier que le NAS est monté
if [ ! -d "$BACKUP_ROOT" ]; then
    log "ERREUR : Le répertoire de sauvegarde $BACKUP_ROOT n'existe pas."
    log "Vérifie que le NAS est monté correctement."
    exit 1
fi

# Vérifier l'espace disque
AVAILABLE_SPACE=$(df -h "$BACKUP_ROOT" | awk 'NR==2 {print $4}' | tr -d 'G')
if [ "$AVAILABLE_SPACE" -lt 100 ]; then
    log "ATTENTION : Moins de 100GB disponibles sur $BACKUP_ROOT ($AVAILABLE_SPACE GB)"
    log "La sauvegarde pourrait échouer."
fi

log "Démarrage de la sauvegarde complète du homelab..."

# ============================================================================
# 1. Sauvegarder les configurations Docker
# ============================================================================

log "=== Sauvegarde des configurations Docker ==="

# Sauvegarder daemon.json
if [ -f "/etc/docker/daemon.json" ]; then
    mkdir -p "$BACKUP_DIR/docker"
    cp /etc/docker/daemon.json "$BACKUP_DIR/docker/"
    log "✓ daemon.json sauvegardé"
else
    log "⚠ /etc/docker/daemon.json non trouvé"
fi

# Sauvegarder les volumes Docker (métadonnées)
mkdir -p "$BACKUP_DIR/docker/volumes"
log "Sauvegarde des métadonnées des volumes Docker..."
docker volume ls -q | while read volume; do
    mkdir -p "$BACKUP_DIR/docker/volumes/$volume"
    docker run --rm \
        -v "$volume:/volume" \
        -v "$BACKUP_DIR/docker/volumes/$volume:/backup" \
        alpine tar cvf /backup/volume-$DATE.tar /volume 2>> "$LOG_FILE"
    log "✓ Volume $volume sauvegardé (métadonnées)"
done

# Sauvegarder les réseaux Docker
mkdir -p "$BACKUP_DIR/docker/networks"
docker network ls --format '{{.Name}}' | grep -v '^bridge$' | grep -v '^host$' | grep -v '^none$' | while read network; do
    docker network inspect "$network" > "$BACKUP_DIR/docker/networks/$network-$DATE.json" 2>> "$LOG_FILE"
    log "✓ Réseau $network sauvegardé"
done

# Sauvegarder la liste des conteneurs
mkdir -p "$BACKUP_DIR/docker/containers"
docker ps -a --format '{{.Names}}' > "$BACKUP_DIR/docker/containers/list-$DATE.txt"
log "✓ Liste des conteneurs sauvegardée"

# Sauvegarder les configurations des conteneurs (docker-compose)
for container in $(docker ps -a --format '{{.Names}}'); do
    docker inspect "$container" > "$BACKUP_DIR/docker/containers/$container-$DATE.json" 2>> "$LOG_FILE"
    log "✓ Configuration de $container sauvegardée"
done

# ============================================================================
# 2. Sauvegarder les configurations système
# ============================================================================

log "=== Sauvegarde des configurations système ==="

# Fichiers de configuration importants
SYSTEM_FILES=(
    "/etc/netplan/00-installer-config.yaml"
    "/etc/hosts"
    "/etc/fstab"
    "/etc/ufw/ufw.conf"
    "/etc/fail2ban/jail.local"
    "/etc/nut/ups.conf"
    "/etc/nut/upsmon.conf"
    "/etc/cloudflared/config.yml"
)

mkdir -p "$BACKUP_DIR/system"

for file in "${SYSTEM_FILES[@]}"; do
    if [ -f "$file" ]; then
        # Créer la structure de répertoires
        dest_dir="$BACKUP_DIR/system/$(dirname "$file")"
        mkdir -p "$dest_dir"
        cp "$file" "$dest_dir/" 2>> "$LOG_FILE"
        log "✓ $file sauvegardé"
    else
        log "⚠ $file non trouvé"
    fi
done

# Sauvegarder les clés SSH (si autorisé)
if [ -d "$HOME/.ssh" ]; then
    mkdir -p "$BACKUP_DIR/system/ssh"
    cp "$HOME/.ssh/config" "$BACKUP_DIR/system/ssh/" 2>> "$LOG_FILE"
    cp "$HOME/.ssh/authorized_keys" "$BACKUP_DIR/system/ssh/" 2>> "$LOG_FILE"
    log "✓ Fichiers SSH sauvegardés (sans clés privées)"
fi

# Sauvegarder les crontabs
crontab -l > "$BACKUP_DIR/system/crontab-$USER-$DATE.txt" 2>> "$LOG_FILE"
log "✓ Crontab sauvegardé"

# ============================================================================
# 3. Sauvegarder les données des services
# ============================================================================

log "=== Sauvegarde des données des services ==="

# Nextcloud
if [ -d "/mnt/nas/nextcloud" ]; then
    mkdir -p "$BACKUP_DIR/services/nextcloud"
    log "Sauvegarde de Nextcloud..."
    tar -czf "$BACKUP_DIR/services/nextcloud/nextcloud-data-$DATE.tar.gz" \
        --exclude="*.log" \
        --exclude="cache/*" \
        --exclude="tmp/*" \
        /mnt/nas/nextcloud 2>> "$LOG_FILE"
    log "✓ Nextcloud sauvegardé"
fi

# Coolify
if [ -d "/mnt/nas/appdata/coolify" ]; then
    mkdir -p "$BACKUP_DIR/services/coolify"
    log "Sauvegarde de Coolify..."
    tar -czf "$BACKUP_DIR/services/coolify/coolify-data-$DATE.tar.gz" \
        --exclude="*.log" \
        --exclude="tmp/*" \
        /mnt/nas/appdata/coolify 2>> "$LOG_FILE"
    log "✓ Coolify sauvegardé"
fi

# Uptime Kuma
if [ -d "/mnt/nas/appdata/uptime-kuma" ]; then
    mkdir -p "$BACKUP_DIR/services/uptime-kuma"
    log "Sauvegarde de Uptime Kuma..."
    tar -czf "$BACKUP_DIR/services/uptime-kuma/uptime-kuma-data-$DATE.tar.gz" \
        /mnt/nas/appdata/uptime-kuma 2>> "$LOG_FILE"
    log "✓ Uptime Kuma sauvegardé"
fi

# ============================================================================
# 4. Sauvegarder les bases de données (si Docker n'est pas disponible)
# ============================================================================

log "=== Sauvegarde des bases de données ==="

# Sauvegarder les conteneurs de base de données
DATABASE_CONTAINERS=("coolify-db")

for db_container in "${DATABASE_CONTAINERS[@]}"; do
    if docker ps -a --format '{{.Names}}' | grep -q "^${db_container}$"; then
        mkdir -p "$BACKUP_DIR/databases"
        log "Sauvegarde de $db_container..."
        docker exec "$db_container" pg_dumpall -U coolify > "$BACKUP_DIR/databases/$db_container-$DATE.sql" 2>> "$LOG_FILE"
        log "✓ Base de données $db_container sauvegardée"
    else
        log "⚠ Conteneur $db_container non trouvé"
    fi
done

# ============================================================================
# 5. Sauvegarder la documentation
# ============================================================================

log "=== Sauvegarde de la documentation ==="

if [ -d "/Users/stephane/Projects/homelab/Documents" ]; then
    mkdir -p "$BACKUP_DIR/documentation"
    cp -r /Users/stephane/Projects/homelab/Documents "$BACKUP_DIR/documentation/" 2>> "$LOG_FILE"
    log "✓ Documentation sauvegardée"
fi

# ============================================================================
# 6. Créer un fichier de résumé
# ============================================================================

log "=== Création du fichier de résumé ==="

cat > "$BACKUP_DIR/RESUME-$DATE.txt" << EOF
=== SAUVEGARDE HOMELAB - $DATE ===

Répertoire de sauvegarde : $BACKUP_DIR
Taille totale : $(du -sh "$BACKUP_DIR" | cut -f1)

=== CONTENU ===

1. Configurations Docker
   - daemon.json
   - Volumes (métadonnées)
   - Réseaux
   - Conteneurs (configurations)

2. Configurations Système
   - netplan
   - hosts
   - fstab
   - ufw
   - fail2ban
   - nut
   - cloudflared
   - SSH
   - Crontabs

3. Données des Services
   - Nextcloud
   - Coolify
   - Uptime Kuma

4. Bases de données
   - coolify-db

5. Documentation
   - Tous les fichiers dans Documents/

=== COMMANDES POUR RESTAURER ===

Pour restaurer complètement :
1. Arrêter tous les conteneurs : docker stop \(docker ps -aq\)
2. Supprimer les anciens volumes : docker system prune -a --volumes
3. Copier les fichiers de sauvegarde aux bons emplacements
4. Redémarrer les conteneurs

Voir le fichier de log pour plus de détails : $LOG_FILE

=== STATUT ===
Statut : TERMINÉ
Date : $DATE
Durée : $(echo "$(date +%s) - $(stat -c %Y "$LOG_FILE")" | bc)s
EOF

log "✓ Fichier de résumé créé"

# ============================================================================
# 7. Nettoyage des anciennes sauvegardes
# ============================================================================

log "=== Nettoyage des anciennes sauvegardes ==="

# Supprimer les sauvegardes de plus de RETENTION_DAYS jours
find "$BACKUP_ROOT" -type d -name "20*" -mtime +"$RETENTION_DAYS" -exec rm -rf {} \; 2>> "$LOG_FILE"

# Compter le nombre de sauvegardes conservées
BACKUP_COUNT=$(find "$BACKUP_ROOT" -type d -name "20*" | wc -l)
log "✓ $BACKUP_COUNT sauvegardes conservées (rétention : $RETENTION_DAYS jours)"

# ============================================================================
# 8. Calculer la taille totale et vérifier
# ============================================================================

log "=== Statistiques de la sauvegarde ==="

# Taille totale de la sauvegarde
BACKUP_SIZE=$(du -sh "$BACKUP_DIR" | cut -f1)
log "Taille totale de la sauvegarde : $BACKUP_SIZE"

# Taille du répertoire de sauvegarde
BACKUP_ROOT_SIZE=$(du -sh "$BACKUP_ROOT" | cut -f1)
log "Taille totale de $BACKUP_ROOT : $BACKUP_ROOT_SIZE"

# Vérifier l'intégrité des fichiers
log "Vérification de l'intégrité des archives..."
find "$BACKUP_DIR" -name "*.tar.gz" -exec tar -tzf {} >/dev/null 2>> "$LOG_FILE" \;

# ============================================================================
# Fin du script
# ============================================================================

log "=== Sauvegarde terminée avec succès ==="
log ""
log "Résumé :"
log "  - Répertoire : $BACKUP_DIR"
log "  - Taille : $BACKUP_SIZE"
log "  - Logs : $LOG_FILE"
log "  - Résumé : $BACKUP_DIR/RESUME-$DATE.txt"
log ""
log "Pour restaurer, utilise le script : restore-homelab.sh"

# Envoyer une notification (optionnel)
if command -v notify-send &> /dev/null; then
    notify-send "Sauvegarde Homelab" "Sauvegarde terminée : $BACKUP_SIZE"
fi

exit 0
