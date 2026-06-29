#!/bin/bash

# ============================================================================
# Script de Mise à Jour des Conteneurs Docker
# ============================================================================
# **Auteur** : Stéphane
# **Dernière mise à jour** : 24 juin 2026
# **Description** : Met à jour tous les conteneurs Docker avec notification
# **Usage** : bash /Users/stephane/Projects/homelab/scripts/update-containers.sh
#
# ============================================================================

# Configuration
# ============================================================================

# Fichier de log
LOG_FILE="/mnt/nas/backups/homelab/update-containers-$(date +%Y%m%d_%H%M%S).log"

# Fichier pour suivre les mises à jour
UPDATE_TRACKER="/mnt/nas/backups/homelab/container-updates.log"

# Exclure ces conteneurs de la mise à jour automatique
EXCLUDED_CONTAINERS=(
    "nextcloud-aio-mastercontainer"  # Nextcloud AIO gère ses propres mises à jour
    "watchtower"                     # Watchtower lui-même
)

# ============================================================================
# Initialisation
# ============================================================================

# Créer les répertoires
mkdir -p "$(dirname "$LOG_FILE")"
mkdir -p "$(dirname "$UPDATE_TRACKER")"

# Fonction de logging
log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# Fonction pour envoyer une notification
notify() {
    local title="Mise à jour Conteneurs Docker"
    local message="$1"
    
    # Notification desktop (si disponible)
    if command -v notify-send &> /dev/null; then
        notify-send "$title" "$message"
    fi
    
    # Notification Telegram (si configuré)
    if [ -f "$HOME/.telegram-bot-token" ]; then
        TELEGRAM_BOT_TOKEN=$(cat "$HOME/.telegram-bot-token")
        TELEGRAM_CHAT_ID=$(cat "$HOME/.telegram-chat-id" 2>/dev/null || echo "")
        if [ -n "$TELEGRAM_BOT_TOKEN" ] && [ -n "$TELEGRAM_CHAT_ID" ]; then
            curl -s -X POST "https://api.telegram.org/bot$TELEGRAM_BOT_TOKEN/sendMessage" \
                -d chat_id="$TELEGRAM_CHAT_ID" \
                -d text="$message" \
                -d parse_mode="HTML" > /dev/null 2>&1 || true
        fi
    fi
    
    # Log dans le tracker
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $message" >> "$UPDATE_TRACKER"
}

# ============================================================================
# Début du script
# ============================================================================

log "=== Début de la mise à jour des conteneurs Docker ==="
log ""

# Vérifier que Docker est en cours d'exécution
if ! docker info > /dev/null 2>&1; then
    log "ERREUR : Docker n'est pas en cours d'exécution."
    notify "❌ ERREUR : Docker n'est pas démarré"
    exit 1
fi

# Vérifier la connexion internet
if ! ping -c 1 8.8.8.8 > /dev/null 2>&1; then
    log "ERREUR : Pas de connexion internet."
    notify "❌ ERREUR : Pas de connexion internet"
    exit 1
fi

# ============================================================================
# 1. Vérifier les conteneurs à mettre à jour
# ============================================================================

log "=== Vérification des conteneurs à mettre à jour ==="

# Obtenir la liste de tous les conteneurs
total_containers=$(docker ps -a --format '{{.Names}}' | wc -l)
log "Nombre total de conteneurs : $total_containers"

# Conteneurs en cours d'exécution
running_containers=$(docker ps --format '{{.Names}}')
stopped_containers=$(docker ps -a --filter "status=exited" --format '{{.Names}}')

log "Conteneurs en cours d'exécution : $(echo "$running_containers" | wc -w)"
log "Conteneurs arrêtés : $(echo "$stopped_containers" | wc -w)"

# ============================================================================
# 2. Mettre à jour les images
# ============================================================================

log ""
log "=== Mise à jour des images Docker ==="

# Pour chaque conteneur en cours d'exécution (sauf ceux exclus)
updated_count=0
failed_count=0
skipped_count=0

for container in $running_containers; do
    # Vérifier si le conteneur est dans la liste d'exclusion
    if printf '%s\n' "${EXCLUDED_CONTAINERS[@]}" | grep -q "^${container}$"; then
        log "⊘ $container : Exclu de la mise à jour automatique"
        skipped_count=$((skipped_count + 1))
        continue
    fi
    
    log "Traitement de $container..."
    
    # Obtenir l'image du conteneur
    image=$(docker inspect --format '{{.Config.Image}}' "$container" 2>> "$LOG_FILE")
    
    # Extraire le nom de l'image (sans le tag)
    image_name=$(echo "$image" | cut -d':' -f1)
    image_tag=$(echo "$image" | cut -d':' -f2)
    
    # Si pas de tag, utiliser 'latest'
    if [ "$image_name" = "$image" ]; then
        image_tag="latest"
    fi
    
    log "  Image actuelle : $image_name:$image_tag"
    
    # Vérifier si une nouvelle image est disponible
    log "  Vérification de $image_name:$image_tag..."
    
    # Tirer la nouvelle image
    if docker pull "$image_name:$image_tag" >> "$LOG_FILE" 2>&1; then
        log "  ✓ Nouvelle image disponible pour $image_name:$image_tag"
        
        # Arrêter le conteneur
        if docker stop "$container" >> "$LOG_FILE" 2>&1; then
            log "  ✓ Conteneur $container arrêté"
        else
            log "  ⚠ Échec de l'arrêt de $container"
            failed_count=$((failed_count + 1))
            continue
        fi
        
        # Supprimer l'ancien conteneur
        if docker rm "$container" >> "$LOG_FILE" 2>&1; then
            log "  ✓ Ancien conteneur $container supprimé"
        else
            log "  ⚠ Échec de la suppression de $container"
            failed_count=$((failed_count + 1))
            continue
        fi
        
        # Recréer le conteneur avec la nouvelle image
        # (En gardant les mêmes options de démarrage)
        # Note : Cela suppose que le conteneur a été créé avec docker run
        # Pour les conteneurs créés avec docker-compose, utiliser une autre méthode
        
        # Obtenir les options de démarrage du conteneur
        run_options=$(docker inspect --format '{{json .HostConfig}}' "$container" 2>> "$LOG_FILE")
        
        # Pour simplifier, on va juste redémarrer avec la nouvelle image
        # et les mêmes montages et variables d'environnement
        
        # Obtenir les montages
        mounts=$(docker inspect --format '{{json .Mounts}}' "$container" 2>> "$LOG_FILE")
        
        # Obtenir les variables d'environnement
        env_vars=$(docker inspect --format '{{json .Config.Env}}' "$container" 2>> "$LOG_FILE")
        
        # Obtenir le réseau
        network=$(docker inspect --format '{{range .NetworkSettings.Networks}}{{.NetworkID}}{{end}}' "$container" 2>> "$LOG_FILE")
        
        # Obtenir les ports
        ports=$(docker inspect --format '{{json .NetworkSettings.Ports}}' "$container" 2>> "$LOG_FILE")
        
        # Pour les conteneurs docker-compose, c'est plus simple de faire :
        # docker-compose -f <fichier>.yml pull && docker-compose -f <fichier>.yml up -d
        
        # Vérifier si le conteneur fait partie d'un stack docker-compose
        if docker inspect --format '{{.Config.Labels.com_docker_compose_project}}' "$container" > /dev/null 2>&1; then
            project=$(docker inspect --format '{{.Config.Labels.com_docker_compose_project}}' "$container" 2>> "$LOG_FILE")
            log "  Conteneur fait partie du projet docker-compose : $project"
            
            # Trouver le fichier docker-compose
            compose_file=$(find /Users/stephane/Projects/homelab -name "docker-compose.yml" -o -name "*.yml" | head -n 1)
            
            if [ -n "$compose_file" ]; then
                log "  Mise à jour via docker-compose..."
                
                # Mettre à jour avec docker-compose
                if docker-compose -f "$compose_file" pull >> "$LOG_FILE" 2>&1; then
                    if docker-compose -f "$compose_file" up -d >> "$LOG_FILE" 2>&1; then
                        log "  ✓ Conteneur $container mis à jour via docker-compose"
                        updated_count=$((updated_count + 1))
                    else
                        log "  ⚠ Échec de docker-compose up pour $container"
                        failed_count=$((failed_count + 1))
                    fi
                else
                    log "  ⚠ Échec de docker-compose pull pour $container"
                    failed_count=$((failed_count + 1))
                fi
            else
                log "  ⚠ Fichier docker-compose non trouvé pour $container"
                failed_count=$((failed_count + 1))
            fi
        else
            # Méthode par défaut : créer un nouveau conteneur avec les mêmes options
            log "  Tentative de création d'un nouveau conteneur..."
            
            # Cette méthode est complexe et peut ne pas fonctionner pour tous les conteneurs
            # Il est préférable d'utiliser docker-compose ou de recréer manuellement
            log "  ⚠ Mise à jour manuelle requise pour $container"
            log "  Exécute : docker start $container"
            failed_count=$((failed_count + 1))
        fi
    else
        log "  ✓ $image_name:$image_tag est déjà à jour"
        updated_count=$((updated_count + 1))
    fi
done

# ============================================================================
# 3. Mettre à jour les conteneurs spécifiques (Nextcloud AIO)
# ============================================================================

log ""
log "=== Mise à jour des conteneurs spécifiques ==="

# Nextcloud AIO
if docker ps -a --format '{{.Names}}' | grep -q "nextcloud-aio-mastercontainer"; then
    log "Mise à jour de Nextcloud AIO..."
    
    # Nextcloud AIO a son propre système de mise à jour
    # Voir : https://github.com/nextcloud/all-in-one#how-to-update
    
    # Arrêter le conteneur
    docker stop nextcloud-aio-mastercontainer 2>> "$LOG_FILE"
    
    # Supprimer l'ancien conteneur
    docker rm nextcloud-aio-mastercontainer 2>> "$LOG_FILE"
    
    # Tirer la nouvelle image
    docker pull nextcloud/all-in-one:latest 2>> "$LOG_FILE"
    
    # Recréer le conteneur (en gardant les mêmes volumes)
    # Note : Les données sont persistées dans les volumes
    docker run -d \
        --name nextcloud-aio-mastercontainer \
        --restart unless-stopped \
        -p 127.0.0.1:8080:8080 \
        -p 127.0.0.1:11000:11000 \
        -v nextcloud_aio_mastercontainer:/mnt/docker-aio-config \
        -v /var/run/docker.sock:/var/run/docker.sock:ro \
        -v /mnt/nas/nextcloud/data:/mnt/nas/nextcloud/data \
        nextcloud/all-in-one:latest 2>> "$LOG_FILE"
    
    if [ $? -eq 0 ]; then
        log "✓ Nextcloud AIO mis à jour"
        updated_count=$((updated_count + 1))
    else
        log "⚠ Échec de la mise à jour de Nextcloud AIO"
        failed_count=$((failed_count + 1))
    fi
else
    log "⊘ Nextcloud AIO non trouvé"
    skipped_count=$((skipped_count + 1))
fi

# ============================================================================
# 4. Nettoyage
# ============================================================================

log ""
log "=== Nettoyage ==="

# Supprimer les images non utilisées
log "Suppression des images non utilisées..."
docker image prune -f >> "$LOG_FILE" 2>&1
log "✓ Images non utilisées supprimées"

# Supprimer les conteneurs et réseaux inutilisés (optionnel)
# log "Suppression des conteneurs et réseaux inutilisés..."
# docker system prune -f >> "$LOG_FILE" 2>&1
# log "✓ Système nettoyé"

# ============================================================================
# 5. Résumé
# ============================================================================

log ""
log "=== Résumé de la mise à jour ==="
log "Conteneurs mis à jour : $updated_count"
log "Conteneurs échoués : $failed_count"
log "Conteneurs exclus : $skipped_count"

# Calculer le pourcentage de succès
total_processed=$((updated_count + failed_count))
if [ $total_processed -gt 0 ]; then
    success_rate=$((updated_count * 100 / total_processed))
    log "Taux de succès : $success_rate%"
fi

# Vérifier les conteneurs en cours d'exécution
running_after=$(docker ps --format '{{.Names}}' | wc -w)
log "Conteneurs en cours d'exécution après la mise à jour : $running_after"

# ============================================================================
# 6. Notification
# ============================================================================

if [ $failed_count -eq 0 ]; then
    message="✅ Mise à jour terminée avec succès !\n\n$updated_count conteneur(s) mis à jour\n$skipped_count conteneur(s) exclus\nTaux de succès : $success_rate%"
    notify "$message"
    log "✓ Notification de succès envoyée"
else
    message="⚠️ Mise à jour terminée avec des erreurs\n\n$updated_count succèss\n$failed_count échecs\n$skipped_count exclus"
    notify "$message"
    log "⚠ Notification d'avertissement envoyée"
fi

log ""
log "=== Mise à jour terminée ==="
log "Fichier de log : $LOG_FILE"
log "Historique : $UPDATE_TRACKER"

exit 0
