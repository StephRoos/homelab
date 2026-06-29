# Configurations Système pour le Homelab

> **Dernière mise à jour** : 24 juin 2026
> **Environnement** : Ubuntu 24.04.4 LTS sur UM880 Plus

---

## 📁 Fichiers de Configuration

| Fichier | Description | Emplacement | Statut |
|--------|-------------|-------------|--------|
| [`netplan.yaml`](netplan.yaml) | Configuration réseau (IP statique) | `/etc/netplan/00-installer-config.yaml` | ✅ Actif |
| [`ufw-rules.txt`](ufw-rules.txt) | Règles du pare-feu UFW | `/etc/ufw/` | ✅ Actif |
| [`fail2ban-jail.local`](fail2ban-jail.local) | Configuration Fail2Ban | `/etc/fail2ban/jail.local` | ✅ Actif |

---

## 🌐 Configuration Réseau (Netplan)

### Fichier : `netplan.yaml`

**Emplacement** : `/etc/netplan/00-installer-config.yaml`

**Appliquer la configuration** :
```bash
# Copier le fichier
sudo cp /Users/stephane/Projects/homelab/configs/system/netplan.yaml /etc/netplan/00-installer-config.yaml

# Appliquer les changements
sudo netplan apply

# Vérifier la configuration
ip addr show enp2s0
```

**Vérifier la connectivité** :
```bash
# Tester la connexion internet
ping -c 4 8.8.8.8

# Tester la résolution DNS
ping -c 4 google.com

# Tester la connexion au NAS
ping -c 4 192.168.129.21
```

**Dépannage** :
- Si la connexion est perdue après `netplan apply`, utilise la console physique ou un accès KVM
- Vérifie les logs : `journalctl -xe`
- Reviens à la configuration DHCP si nécessaire

---

## 🔒 Pare-feu (UFW)

### Configuration actuelle

Le pare-feu UFW est **activé** avec les règles suivantes :

| Règle | Port | Protocole | Source | Description |
|-------|------|-----------|--------|-------------|
| Default | ALL | ALL | ANY | DENY IN |
| Default | ALL | ALL | ANY | ALLOW OUT |
| SSH | 22 | TCP | 192.168.129.0/24 | Accès SSH depuis le LAN |
| ICMP | - | ICMP | 192.168.129.0/24 | Ping depuis le LAN |

**Note importante** : Les services exposés sur internet (Coolify, Nextcloud, Uptime Kuma) sont **accessibles uniquement via Cloudflare Tunnel**. Aucun port n'est ouvert directement sur l'hôte.

### Appliquer les règles

```bash
# Activer UFW (si ce n'est pas déjà fait)
sudo ufw enable

# Appliquer les règles depuis le fichier
# (Le fichier ufw-rules.txt contient les commandes à exécuter)

# Vérifier le statut
sudo ufw status verbose
```

### Commandes utiles

```bash
# Voir le statut
sudo ufw status

# Voir le statut détaillé
sudo ufw status verbose

# Voir les règles numérotées
sudo ufw status numbered

# Ajouter une règle temporaire (pour test)
sudo ufw allow 8080/tcp

# Supprimer une règle
sudo ufw delete allow 8080/tcp

# Recharger UFW
sudo ufw reload

# Désactiver UFW (temporairement)
sudo ufw disable
```

---

## 🛡️ Fail2Ban

### Configuration actuelle

Fail2Ban est **activé** avec la configuration suivante :

- **Jail SSH** : Activée, maxretry=5, bantime=1h
- **Période de détection** : 10 minutes
- **IPs ignorées** : 127.0.0.1, ::1, 192.168.129.0/24 (réseau local)

### Appliquer la configuration

```bash
# Copier le fichier de configuration
sudo cp /Users/stephane/Projects/homelab/configs/system/fail2ban-jail.local /etc/fail2ban/jail.local

# Recharger Fail2Ban
sudo fail2ban-client reload

# Redémarrer Fail2Ban
sudo systemctl restart fail2ban

# Vérifier le statut
sudo fail2ban-client status
```

### Commandes utiles

```bash
# Voir le statut général
sudo fail2ban-client status

# Voir le statut d'une jail spécifique
sudo fail2ban-client status sshd

# Voir les IPs bannies
sudo fail2ban-client status sshd | grep "Banned IP"

# Débannir une IP
sudo fail2ban-client set sshd unbanip 1.2.3.4

# Voir les logs
sudo tail -f /var/log/fail2ban.log

# Tester la configuration
sudo fail2ban-client -t
```

### Activer des jails supplémentaires

Pour activer la protection Fail2Ban pour d'autres services :

1. Modifie `fail2ban-jail.local` et change `enabled = false` en `enabled = true`
2. Crée les filtres nécessaires dans `/etc/fail2ban/filter.d/`
3. Recharge Fail2Ban : `sudo fail2ban-client reload`

---

## 📊 Monitoring Système

### Services de monitoring actifs

| Service | Port | Description | Statut |
|---------|------|-------------|--------|
| **NUT** | - | Monitoring UPS Eaton | ✅ Actif |
| **Uptime Kuma** | 3001 | Monitoring des services | ✅ Actif |
| **Cloudflared** | - | Tunnel Cloudflare | ✅ Actif |

### Commandes de monitoring

```bash
# Voir les services actifs
systemctl list-units --type=service --state=running

# Voir l'utilisation CPU/RAM/Disk
htop
free -h
df -h

# Voir l'utilisation réseau
iftop -i enp2s0

# Voir les connexions actives
ss -tulnp
netstat -tulnp

# Voir les processus
ps aux
```

---

## 🔋 NUT (Network UPS Tools) - Eaton 1600

### Configuration

Le service NUT est configuré pour monitorer l'UPS Eaton Ellipse PRO 1600.

**Fichiers de configuration** :
- `/etc/nut/ups.conf` - Configuration de l'UPS
- `/etc/nut/upsmon.conf` - Monitoring
- `/etc/nut/nut.conf` - Configuration générale

**Commandes utiles** :
```bash
# Voir le statut de NUT
sudo systemctl status nut-server
sudo systemctl status nut-monitor

# Voir l'état de l'UPS
upsc eaton

# Voir les logs
sudo tail -f /var/log/nut/nut.log

# Forcer l'arrêt du serveur (simulation coupure)
sudo upscmd -u admin -p <password> eaton shutdown.return

# Tester la connexion USB
lsusb | grep Eaton
```

---

## 📅 Maintenance Système

### Mises à jour

```bash
# Mettre à jour la liste des paquets
sudo apt update

# Mettre à jour les paquets
sudo apt upgrade -y

# Nettoyer les paquets inutiles
sudo apt autoremove

# Mettre à jour le noyau (si nécessaire)
sudo apt dist-upgrade -y
```

### Sauvegardes

**Configuration actuelle** :
- Sauvegardes NFS vers `/mnt/nas/backups/`
- Utilisation de `rsync` pour les sauvegardes incrémentielles

**Exemple de script de sauvegarde** :
```bash
#!/bin/bash
# Sauvegarde des données importantes

DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_DIR="/mnt/nas/backups/homelab"

# Créer le répertoire de sauvegarde
mkdir -p "$BACKUP_DIR/$DATE"

# Sauvegarder les configurations Docker
rsync -avz /var/lib/docker/volumes/ "$BACKUP_DIR/$DATE/docker-volumes/"

# Sauvegarder les configurations système
rsync -avz /etc/ "$BACKUP_DIR/$DATE/etc/"
rsync -avz /home/ "$BACKUP_DIR/$DATE/home/"

# Sauvegarder les conteneurs (optionnel)
docker ps -a --format '{{.Names}}' | while read container; do
    docker commit "$container" "$container-$DATE"
    docker save "$container-$DATE" > "$BACKUP_DIR/$DATE/$container.tar"
done

# Nettoyer les anciennes sauvegardes (30 jours)
find "$BACKUP_DIR" -type d -mtime +30 -exec rm -rf {} \;
```

---

## 🔧 Dépannage Système

### Problèmes courants

#### 1. SSH ne fonctionne pas

**Diagnostic** :
```bash
# Vérifier que SSH est en cours d'exécution
sudo systemctl status sshd

# Vérifier les logs SSH
sudo tail -f /var/log/auth.log

# Vérifier les permissions
ls -la ~/.ssh/
ls -la ~/.ssh/authorized_keys
```

**Solutions** :
```bash
# Vérifier la configuration
sudo sshd -t

# Redémarrer SSH
sudo systemctl restart sshd

# Vérifier les permissions (doit être 600 pour authorized_keys, 700 pour .ssh)
chmod 600 ~/.ssh/authorized_keys
chmod 700 ~/.ssh
```

#### 2. Réseau ne fonctionne pas

**Diagnostic** :
```bash
# Vérifier l'interface réseau
ip addr show enp2s0

# Vérifier la connectivité
ping 192.168.129.1
ping 8.8.8.8

# Vérifier la résolution DNS
nslookup google.com
```

**Solutions** :
```bash
# Redémarrer le réseau
sudo systemctl restart systemd-networkd

# Appliquer la configuration Netplan
sudo netplan apply

# Redémarrer le serveur (si nécessaire)
sudo reboot
```

#### 3. Docker ne fonctionne pas

**Diagnostic** :
```bash
# Vérifier que Docker est en cours d'exécution
sudo systemctl status docker

# Vérifier les logs Docker
sudo journalctl -u docker

# Vérifier le disque
df -h
```

**Solutions** :
```bash
# Redémarrer Docker
sudo systemctl restart docker

# Nettoyer Docker
sudo docker system prune

# Vérifier la configuration
sudo dockerd --debug
```

---

## 📚 Documentation Complémentaire

- [Ubuntu Server 24.04 LTS Docs](https://ubuntu.com/server/docs)
- [Netplan Documentation](https://netplan.io/)
- [UFW Documentation](https://help.ubuntu.com/community/UFW)
- [Fail2Ban Documentation](https://www.fail2ban.org/wiki/index.php/Main_Page)
- [NUT Documentation](https://networkupstools.org/)
