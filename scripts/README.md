# Scripts pour le Homelab

> **Dernière mise à jour** : 25 juin 2026
> **Environnement** : UM880 Plus (Ubuntu 24.04) + NAS UGREEN (UGOS 6.1.84)

---

## 📁 Structure des Fichiers

```
scripts/
├── README.md                      # ← Ce fichier
├── backup-homelab.sh              # Sauvegarde complète du homelab
├── restore-homelab.sh             # Restauration des sauvegardes
├── update-containers.sh           # Mise à jour des conteneurs Docker
├── deploy-immich.sh               # Déploiement initial d'Immich
├── backup-immich.sh               # Sauvegarde spécifique Immich
├── restore-immich.sh              # Restauration spécifique Immich
└── migrate-immich-photos.sh       # Migration des photos vers Immich
```

---

## 📋 Table des Matières
1. [Scripts Généraux](#-scripts-généraux)
2. [Scripts Spécifiques Immich](#-scripts-spécifiques-immich)
3. [Configuration](#-configuration)
4. [Planification](#-planification)
5. [Sécurité](#-sécurité)
6. [Dépannage](#-dépannage)

---

## 🚀 Scripts Disponibles

### 📦 Scripts Généraux

#### 1. `backup-homelab.sh` - Sauvegarde Complète

**Description** : Effectue une sauvegarde complète de ton homelab (Docker, système, configs, données).

**Fonctionnalités** :
- Sauvegarde des configurations Docker (daemon.json, volumes, réseaux, conteneurs)
- Sauvegarde des configurations système (netplan, UFW, Fail2Ban, NUT, SSH, crontabs)
- Sauvegarde des données des services (Nextcloud, Coolify, Uptime Kuma)
- Sauvegarde des bases de données (PostgreSQL pour Coolify)
- Sauvegarde de la documentation
- Nettoyage automatique des anciennes sauvegardes (30 jours de rétention)
- Vérification de l'intégrité des archives
- Notification desktop (si disponible)

**Usage** :
```bash
# Exécuter une sauvegarde complète
sudo bash /Users/stephane/Projects/homelab/scripts/backup-homelab.sh

# Planifier une sauvegarde quotidienne (via cron)
(crontab -l ; echo "0 3 * * * /Users/stephane/Projects/homelab/scripts/backup-homelab.sh") | crontab -
```

**Emplacement des sauvegardes** :
```
/mnt/nas/backups/homelab/
├── 20260624_120000/          # Sauvegarde du 24 juin 2026 à 12:00:00
│   ├── docker/
│   │   ├── daemon.json
│   │   ├── volumes/
│   │   ├── networks/
│   │   └── containers/
│   ├── system/
│   │   ├── etc/
│   │   ├── netplan.yaml
│   │   └── ssh/
│   ├── services/
│   │   ├── nextcloud/
│   │   ├── coolify/
│   │   └── uptime-kuma/
│   ├── databases/
│   │   └── coolify-db-20260624_120000.sql
│   ├── documentation/
│   └── RESUME-20260624_120000.txt
├── 20260625_120000/          # Sauvegarde du 25 juin
│   └── ...
└── backup-20260624_120000.log # Logs de la sauvegarde
```

**Options de personnalisation** :
- Modifier `BACKUP_ROOT` pour changer l'emplacement
- Modifier `RETENTION_DAYS` pour changer la durée de rétention
- Modifier `EXCLUDED_CONTAINERS` pour exclure certains conteneurs

---

### 2. `restore-homelab.sh` - Restauration

**Description** : Restaure une sauvegarde complète ou partielle du homelab.

**Fonctionnalités** :
- Menu interactif pour choisir ce qu'on veut restaurer
- Restauration complète (tout écraser et restaurer)
- Restauration par composant (Docker, système, services, bases de données, documentation)
- Affichage du contenu de la sauvegarde
- Sauvegarde des configurations actuelles avant restauration (rollback possible)
- Confirmation pour les opérations dangereuses

**Usage** :
```bash
# Restaurer la sauvegarde la plus récente
sudo bash /Users/stephane/Projects/homelab/scripts/restore-homelab.sh

# Restaurer une sauvegarde spécifique
sudo bash /Users/stephane/Projects/homelab/scripts/restore-homelab.sh 20260624_120000

# Voir le contenu d'une sauvegarde
sudo bash /Users/stephane/Projects/homelab/scripts/restore-homelab.sh 20260624_120000
```

**Menu interactif** :
```
=== MENU DE RESTAURATION HOMELAB ===

Sauvegarde sélectionnée : 20260624_120000

Choisissez ce que vous voulez restaurer :

1) Tout restaurer (COMPLET - Attention : écrase tout !)
2) Configurations Docker uniquement
3) Configurations système uniquement
4) Données des services uniquement
5) Bases de données uniquement
6) Documentation uniquement
7) Afficher le contenu de la sauvegarde
8) Quitter
```

**Notes** :
- **Doit être exécuté en tant que root** (`sudo`)
- **Fait une sauvegarde des configurations actuelles** avant de restaurer
- **Pour la restauration complète**, confirme avec "oui" quand demandé

---

### 3. `update-containers.sh` - Mise à Jour des Conteneurs

**Description** : Met à jour tous les conteneurs Docker de manière sécurisée.

**Fonctionnalités** :
- Vérification des prérequis (Docker, connexion internet)
- Détection automatique des conteneurs en cours d'exécution
- Exclusion des conteneurs sensibles (Nextcloud AIO, Watchtower)
- Mise à jour via `docker-compose pull` et `docker-compose up -d` pour les stacks
- Gestion spéciale pour Nextcloud AIO (qui a son propre système de mise à jour)
- Nettoyage des images non utilisées
- Notification desktop et Telegram (si configuré)
- Historique des mises à jour

**Usage** :
```bash
# Exécuter manuellement
bash /Users/stephane/Projects/homelab/scripts/update-containers.sh

# Planifier une mise à jour quotidienne (via cron)
(crontab -l ; echo "0 4 * * * /Users/stephane/Projects/homelab/scripts/update-containers.sh") | crontab -

# Planifier une mise à jour hebdomadaire (le dimanche à 4h)
(crontab -l ; echo "0 4 * * 0 /Users/stephane/Projects/homelab/scripts/update-containers.sh") | crontab -
```

**Configuration des notifications Telegram** :
1. Créer un fichier `~/.telegram-bot-token` avec ton token bot
2. Créer un fichier `~/.telegram-chat-id` avec ton chat ID
3. Le script enverra automatiquement les notifications

**Conteneurs exclus par défaut** :
- `nextcloud-aio-mastercontainer` (Nextcloud AIO gère ses propres mises à jour)
- `watchtower` (Watchtower lui-même)

**Fichiers de log** :
- `/mnt/nas/backups/homelab/update-containers-YYYYMMDD_HHMMSS.log` (log de chaque exécution)
- `/mnt/nas/backups/homelab/container-updates.log` (historique des mises à jour)

---

### 📸 Scripts Spécifiques Immich

#### 4. `deploy-immich.sh` - Déploiement Initial d'Immich

**Description** : Déploie Immich avec toutes les dépendances (PostgreSQL, Redis, etc.)

**Fonctionnalités** :
- Création des dossiers nécessaires sur le NAS
- Vérification de l'environnement Docker
- Déploiement des conteneurs Immich
- Configuration du réseau Docker dédié
- Validation de l'installation

**Usage** :
```bash
# Se connecter à homelab
ssh homelab

# Se placer dans le projet
cd /home/steph/homelab

# Rendre exécutable (si nécessaire)
chmod +x scripts/deploy-immich.sh

# Exécuter le déploiement
./scripts/deploy-immich.sh
```

**Prérequis** :
- Docker et Docker Compose installés
- NAS monté sur `/mnt/nas`
- Fichier `.env` configuré dans `configs/docker/`

---

#### 5. `backup-immich.sh` - Sauvegarde Spécifique Immich

**Description** : Sauvegarde complète de la configuration et des données Immich

**Fonctionnalités** :
- Sauvegarde de la base de données PostgreSQL
- Sauvegarde de la configuration (server et web)
- Sauvegarde optionnelle des volumes Docker
- Génération d'un fichier d'informations avec statistiques
- Nettoyage automatique des anciennes sauvegardes (>30 jours)
- Vérifications pré-sauvegarde (Docker, conteneurs, espace disque)

**Usage** :
```bash
# Exécuter manuellement (sur homelab)
cd /home/steph/homelab
bash scripts/backup-immich.sh

# Planifier une sauvegarde quotidienne
(crontab -l ; echo "0 2 * * * /home/steph/homelab/scripts/backup-immich.sh >> /var/log/immich-backup.log 2>&1") | crontab -
```

**Emplacement des sauvegardes** :
```
/mnt/nas/backups/immich/
├── immich-db-YYYYMMDD_HHMMSS.sql      # Sauvegarde de la base
├── immich-config-YYYYMMDD_HHMMSS.tar.gz  # Configuration
├── immich-info-YYYYMMDD_HHMMSS.txt       # Informations système
└── volumes-YYYYMMDD_HHMMSS/            # Volumes Docker (optionnel)
```

---

#### 6. `restore-immich.sh` - Restauration Immich

**Description** : Restaure une sauvegarde Immich complète

**Fonctionnalités** :
- Arrêt des conteneurs Immich
- Restauration de la base de données
- Restauration de la configuration
- Restauration des volumes Docker (optionnel)
- Redémarrage automatique des conteneurs
- Vérification de la restauration

**Usage** :
```bash
# Restaurer la sauvegarde la plus récente
bash scripts/restore-immich.sh

# Restaurer une sauvegarde spécifique (avec date)
bash scripts/restore-immich.sh 20260625_120000
```

**Prérequis** :
- Conteneurs Immich doivent être déployés
- Volume de sauvegarde disponible

---

#### 7. `migrate-immich-photos.sh` - Migration des Photos

**Description** : Migre les photos depuis un dossier source vers la bibliothèque Immich

**Fonctionnalités** :
- Vérifications pré-migration (Docker, conteneurs, espace disque)
- Comptage des fichiers à migrer
- Migration avec rsync (conserve les métadonnées)
- Support de multiples formats (JPG, PNG, HEIC, MP4, MOV, etc.)
- Exclusion des fichiers temporaires (.DS_Store, Thumbs.db)
- Vérification post-migration
- Fichier de log détaillé

**Usage** :
```bash
# Exécuter la migration (sur homelab)
cd /home/steph/homelab
bash scripts/migrate-immich-photos.sh
```

**Configuration** :
- **SOURCE_DIR** : Dossier source des photos (par défaut `/mnt/nas/photos`)
- **DEST_DIR** : Dossier de destination (par défaut `/mnt/nas/immich/library`)

**Modification des dossiers** :
```bash
# Éditer le script pour changer les répertoires
nano scripts/migrate-immich-photos.sh

# Modifier les variables en haut du script
SOURCE_DIR="/ton/chemin/source"
DEST_DIR="/mnt/nas/immich/library"
```

**Après la migration** :
- Immich scannera automatiquement le dossier `/mnt/nas/immich/library`
- Pour forcer un scan manuel :
  ```bash
  # Via l'interface web : Paramètres → Bibliothèques → Scanner maintenant
  # Via l'API :
  curl -X POST http://localhost:2284/api/library/scan \
    -H "Authorization: Bearer TON_TOKEN" \
    -H "Content-Type: application/json"
  ```

---

## 🔧 Configuration des Scripts

### Variables d'Environnement Utilisées

| Variable | Script | Description | Valeur par défaut |
|----------|--------|-------------|------------------|
| `BACKUP_ROOT` | backup-homelab.sh | Répertoire de sauvegarde | `/mnt/nas/backups/homelab` |
| `RETENTION_DAYS` | backup-homelab.sh | Jours de rétention | `30` |
| `LOG_FILE` | backup-homelab.sh | Fichier de log | `$BACKUP_ROOT/backup-YYYYMMDD_HHMMSS.log` |
| `UPDATE_TRACKER` | update-containers.sh | Historique des mises à jour | `/mnt/nas/backups/homelab/container-updates.log` |

### Personnalisation

Pour modifier les paramètres par défaut :

1. **Éditer le script** :
   ```bash
   nano /Users/stephane/Projects/homelab/scripts/backup-homelab.sh
   ```

2. **Modifier les variables en haut du script** :
   ```bash
   # Exemple pour backup-homelab.sh
   BACKUP_ROOT="/mnt/nas/backups/homelab"
   RETENTION_DAYS=60  # Garder 60 jours au lieu de 30
   ```

3. **Enregistrer et tester** :
   ```bash
   # Tester le script modifié
   sudo bash /Users/stephane/Projects/homelab/scripts/backup-homelab.sh
   ```

---

## 📅 Planification (Cron)

### Exemple de Crontab Complète

```bash
# Éditer la crontab
crontab -e
```

Contenu recommandé :
```bash
# Sauvegardes quotidiennes à 3h
0 3 * * * /Users/stephane/Projects/homelab/scripts/backup-homelab.sh

# Mises à jour des conteneurs tous les lundis à 4h
0 4 * * 1 /Users/stephane/Projects/homelab/scripts/update-containers.sh

# Monitoring du stockage toutes les 6 heures
0 */6 * * * /usr/local/bin/monitor-storage.sh
```

### Vérifier les tâches planifiées

```bash
# Voir la crontab actuelle
crontab -l

# Voir les tâches planifiées pour root
sudo crontab -l

# Voir les logs des exécutions cron
sudo tail -f /var/log/syslog | grep CRON
```

---

## 🐳 Intégration avec Docker (Optionnelle)

Tu peux aussi exécuter ces scripts depuis des conteneurs Docker :

### Exemple : Conteneur de Sauvegarde

```yaml
# docker-compose.yml
version: '3.8'

services:
  backup-manager:
    image: alpine:latest
    container_name: backup-manager
    restart: unless-stopped
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro
      - /mnt/nas:/mnt/nas
      - /etc:/etc:ro
      - /home:/home:ro
      - /var/lib/docker:/var/lib/docker:ro
      - /var/log:/var/log:ro
      - /Users/stephane/Projects/homelab/scripts:/scripts
    command: >
      sh -c "
      while true; do
        /scripts/backup-homelab.sh && \
        /scripts/update-containers.sh;
        sleep 86400;
      done
      "
    deploy:
      resources:
        limits:
          memory: 512M
          cpus: '0.5'
```

**Note** : Cette approche est plus complexe et nécessite une configuration plus poussée des permissions.

---

## 🔒 Sécurité

### Bonnes Pratiques

1. **Permissions** :
   - Les scripts doivent être **exécutables uniquement par root** ou ton utilisateur
   - Ne pas donner de permissions 777
   
   ```bash
   # Bonnes permissions
   chmod 755 /Users/stephane/Projects/homelab/scripts/*.sh
   chown steph:steph /Users/stephane/Projects/homelab/scripts/*.sh
   ```

2. **Backup des scripts** :
   - Sauvegarde tes scripts avec ta documentation
   - Versionne-les avec Git (déjà fait dans ce repo)

3. **Test avant déploiement** :
   - Teste toujours un script manuellement avant de le planifier
   - Vérifie les permissions et les chemins

4. **Logs** :
   - Tous les scripts génèrent des logs
   - Vérifie régulièrement les logs pour détecter les problèmes

---

## 📊 Monitoring des Scripts

### Vérifier que les sauvegardes s'exécutent

```bash
# Vérifier les dernières sauvegardes
ls -lh /mnt/nas/backups/homelab/ | head -n 10

# Voir la taille des sauvegardes
du -sh /mnt/nas/backups/homelab/

# Vérifier les logs de la dernière sauvegarde
tail -n 50 /mnt/nas/backups/homelab/backup-$(date +%Y%m%d)*
```

### Vérifier que les mises à jour s'exécutent

```bash
# Voir l'historique des mises à jour
tail -n 20 /mnt/nas/backups/homelab/container-updates.log

# Vérifier les logs de la dernière mise à jour
tail -n 50 /mnt/nas/backups/homelab/update-containers-$(date +%Y%m%d)*
```

---

## 🚨 Dépannage

### Problème : Le script de sauvegarde échoue

**Diagnostic** :
```bash
# Exécuter le script en mode verbose
sudo bash -x /Users/stephane/Projects/homelab/scripts/backup-homelab.sh

# Voir les erreurs
sudo tail -n 100 /mnt/nas/backups/homelab/backup-*.log
```

**Solutions courantes** :
- **Le NAS n'est pas monté** : Vérifie que `/mnt/nas` est accessible
  ```bash
  mount | grep nfs
  ping 192.168.129.21
  ```
- **Permissions insuffisantes** : Exécute avec `sudo`
- **Espace disque insuffisant** : Vérifie l'espace disponible
  ```bash
  df -h /mnt/nas/backups
  ```

### Problème : Le script de restauration échoue

**Diagnostic** :
```bash
# Exécuter en mode verbose
sudo bash -x /Users/stephane/Projects/homelab/scripts/restore-homelab.sh
```

**Solutions courantes** :
- **La sauvegarde n'existe pas** : Vérifie le chemin et la date
- **Permissions insuffisantes** : Le script doit être exécuté en root
- **Docker n'est pas en cours d'exécution** : Démarre Docker avant de restaurer

### Problème : Le script de mise à jour échoue

**Diagnostic** :
```bash
# Exécuter en mode verbose
bash -x /Users/stephane/Projects/homelab/scripts/update-containers.sh

# Voir les logs
cat /mnt/nas/backups/homelab/update-containers-*.log
```

**Solutions courantes** :
- **Docker n'est pas démarré** : `sudo systemctl start docker`
- **Pas de connexion internet** : Vérifie ta connexion
- **Conteneur verrouillé** : Certains conteneurs peuvent être bloqués

---

## 📚 Documentation Complémentaire

- [Bash Scripting Guide](https://guide.bash.academy/)
- [Cron Guide](https://www.freebsd.org/cgi/man.cgi?crontab)
- [Docker Backup Documentation](https://docs.docker.com/engine/admin/volumes/)

---

## 🎓 Ressources Externes

- [rsync Documentation](https://rsync.samba.org/) - Pour des sauvegardes incrémentielles
- [BorgBackup](https://www.borgbackup.org/) - Alternative à rsync
- [Duplicati](https://www.duplicati.com/) - Sauvegardes chiffrées
- [Rclone](https://rclone.org/) - Synchronisation cloud

---

## 📝 Historique des Modifications

| Date | Script | Modification | Auteur |
|------|--------|--------------|--------|
| 2026-06-24 | backup-homelab.sh | Création initiale | Stéphane |
| 2026-06-24 | restore-homelab.sh | Création initiale | Stéphane |
| 2026-06-24 | update-containers.sh | Création initiale | Stéphane |
| 2026-06-24 | deploy-immich.sh | Création initiale | Stéphane |
| 2026-06-25 | backup-immich.sh | Création pour sauvegardes dédiées | Vibe |
| 2026-06-25 | restore-immich.sh | Création pour restauration dédiée | Vibe |
| 2026-06-25 | migrate-immich-photos.sh | Création pour migration des photos | Vibe |
| 2026-06-25 | README.md | Ajout documentation scripts Immich | Vibe |

---

**Besoin d'aide avec les scripts ?** 

Pose ta question à l'agent **homelab-expert** :
```bash
vibe --agent homelab-expert
```

Puis demande :
```
"Pourquoi mon script backup-homelab.sh échoue-t-il avec l'erreur [erreur] ?"
```
