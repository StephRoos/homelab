# Documentation Technique Homelab - Version 2.0

> **Dernière mise à jour** : 23 juin 2026
> **Version** : 2.0 (Post-audit complet)
> **Statut** : 🟢 Opérationnel et documenté

---

## 📖 Table des Matières

1. [Architecture Globale](#architecture-globale)
2. [Configuration Réseau](#configuration-réseau)
3. [Serveur Principal (UM880 Plus)](#serveur-principal-um880-plus)
4. [NAS UGREEN](#nas-ugreen)
5. [Services et Applications](#services-et-applications)
6. [Sécurité](#sécurité)
7. [Procédures Opérationnelles](#procédures-opérationnelles)
8. [Dépannage](#dépannage)
9. [Maintenance](#maintenance)
10. [Annexes](#annexes)

---

## 🌐 Architecture Globale

### Schéma d'Infrastructure

```
┌───────────────────────────────────────────────────────────────┐
│                        HOMELAB 2026                          │
├─────────────────┬───────────────────────┬─────────────────────┐
│  Serveur        │       NAS            │     Réseau         │
│  UM880 Plus     │   UGREEN NAS        │   192.168.129.0/24 │
│  -------------  │   ---------------   │   ---------------  │
│  Ubuntu 24.04   │   UGOS 6.1.84      │   Switch 2.5GbE   │
│  32GB RAM       │   4GB RAM          │   TP-Link          │
│  Ryzen 7 8845HS │   ARM64            │   TL-SG105-M2      │
│  1TB NVMe       │   3.7TB RAID1      │                   │
└─────────┬───────┴───────┬─────────┬─────────┬─────────┘
          │               │         │         │
          ▼               ▼         ▼         ▼
┌─────────────────┐ ┌─────────────┐ ┌───────┐ ┌───────┐
│  Docker         │ │  NFS        │ │ UPS   │ │ Box   │
│  26 containers  │ │  4 volumes  │ │ Eaton │ │ Internet│
└─────────────────┘ └─────────────┘ └───────┘ └───────┘
```

### Rôles et Responsabilités

| Équipement | Rôle Principal | IP | OS |
|------------|----------------|----|-----|
| UM880 Plus | Serveur principal | 192.168.129.10 | Ubuntu 24.04.4 LTS |
| NAS UGREEN | Stockage & Backup | 192.168.129.21 | UGOS 6.1.84 |
| Switch | Réseau 2.5GbE | N/A | N/A |
| UPS | Alimentation | USB | N/A |

---

## 🌐 Configuration Réseau

### Topologie

```
Internet → Box (192.168.129.1) → Switch → Serveur (192.168.129.10)
                              → NAS (192.168.129.21)
```

### Configuration IP

| Équipement | IP | MAC | Rôle |
|------------|----|-----|------|
| UM880 Plus | 192.168.129.10 | Voir `ip a` | Serveur principal |
| NAS UGREEN | 192.168.129.21 | Voir `ip a` | Stockage |
| Box | 192.168.129.1 | Voir box | Passerelle |

### Configuration DNS

```bash
# /etc/hosts sur tous les équipements
192.168.129.10 homelab homelab.local
192.168.129.21 nas nas.local
```

### Configuration SSH

#### Serveur
```bash
# /etc/ssh/sshd_config
Port 22
PermitRootLogin no
PasswordAuthentication no
PubkeyAuthentication yes
AuthorizedKeysFile .ssh/authorized_keys
```

#### Client (Mac)
```bash
# ~/.ssh/config
Host homelab
  HostName 192.168.129.10
  User steph
  IdentityFile ~/.ssh/id_ed25519
  ServerAliveInterval 60

Host nas
  HostName 192.168.129.21
  User Steph
  IdentityFile ~/.ssh/id_ed25519
```

---

## 🖥️ Serveur Principal (UM880 Plus)

### Spécifications Techniques

| Composant | Détails |
|-----------|---------|
| CPU | AMD Ryzen 7 8845HS (8 cores, 16 threads) |
| RAM | 32GB DDR5-5600 |
| Stockage | 1TB NVMe PCIe 4.0 |
| OS | Ubuntu 24.04.4 LTS |
| Kernel | 6.17.0-35-generic |

### Configuration Système

#### Partitions Disque
```bash
# df -h
Filesystem      Size  Used Avail Use% Mounted on
/dev/nvme0n1p2  937G   53G  837G   6% /
```

#### Utilisateurs
```bash
# Utilisateurs principaux
steph: Administrateur (sudo)
# Pas de root SSH
```

#### Mises à jour
```bash
# Configuration des mises à jour automatiques
# /etc/apt/apt.conf.d/20auto-upgrades
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Unattended-Upgrade "1";
```

### Services Système

#### Docker

**Configuration** (`/etc/docker/daemon.json`)
```json
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  },
  "default-address-pools": [
    {
      "base": "10.0.0.0/8",
      "size": 24
    }
  ],
  "ip": "127.0.0.1"
}
```

**Gestion**
```bash
# Commandes utiles
systemctl status docker
systemctl restart docker
docker ps -a
docker stats
docker logs -f <container>
```

#### Cloudflared

**Configuration**
```bash
# Service systemd
systemctl status cloudflared
journalctl -u cloudflared -f
```

**Tunnel**
```bash
# Voir les tunnels actifs
cloudflared tunnel list
cloudflared tunnel info <tunnel-id>
```

#### Fail2Ban

**Configuration** (`/etc/fail2ban/jail.local`)
```ini
[sshd]
enabled = true
maxretry = 5
bantime = 1h
```

**Gestion**
```bash
fail2ban-client status
fail2ban-client status sshd
fail2ban-client set sshd unbanip <IP>
```

#### NUT (UPS)

**Configuration**
```bash
# /etc/nut/ups.conf
[eaton]
  driver = usbhid-ups
  port = auto
  desc = "Eaton Ellipse PRO 1600"

# /etc/nut/upsmon.conf
MONITOR eaton@localhost 1 upsmonitor <password> primary
```

**Gestion**
```bash
systemctl status nut-server
upsc eaton
upscmd -u admin -p <password> eaton shutdown.return
```

---

## 💾 NAS UGREEN

### Spécifications Techniques

| Composant | Détails |
|-----------|---------|
| CPU | ARM64 (4 cores) |
| RAM | 4GB DDR4 |
| Stockage | 2×4TB HDD (RAID1) = 3.7TB utilisable |
| OS | UGOS 6.1.84 |
| Kernel | Linux 6.1.84 |

### Configuration

#### Volumes

| Volume | Taille | Utilisation | Montage NFS |
|-------|-------|------------|-------------|
| volume1 | 3.7TB | 15% | /mnt/nas/* |

#### Partages NFS

**Configuration** (`/etc/exports`)
```
/volume1/appdata    192.168.129.10(rw,sync,no_subtree_check,noexec,nosuid)
/volume1/backups    192.168.129.10(rw,sync,no_subtree_check,noexec,nosuid)
/volume1/nextcloud  192.168.129.10(rw,sync,no_subtree_check,noexec,nosuid)
/volume1/timemachine 192.168.129.10(rw,sync,no_subtree_check,noexec,nosuid)
```

**Montage côté serveur** (`/etc/fstab`)
```
192.168.129.21:/volume1/appdata /mnt/nas/appdata nfs defaults,_netdev,noexec,nosuid,timeo=30,hard,nofail 0 0
192.168.129.21:/volume1/backups /mnt/nas/backups nfs defaults,_netdev,noexec,nosuid,timeo=30,hard,nofail 0 0
```

#### SSH

**Configuration**
```bash
# Clés autorisées
ls -la ~/.ssh/authorized_keys
# Permissions
chmod 600 ~/.ssh/authorized_keys
chmod 700 ~/.ssh
```

---

## 📦 Services et Applications

### Coolify

**Installation**
```bash
curl -fsSL https://cdn.coollabs.io/coolify/install.sh | bash
```

**Gestion**
```bash
# Accès
docker logs -f coolify
# Mise à jour
docker pull coollabsio/coolify:latest
```

### Nextcloud AIO

**Installation**
```yaml
# docker-compose.yml
version: '3.8'
services:
  nextcloud-aio-mastercontainer:
    image: nextcloud/all-in-one:latest
    container_name: nextcloud-aio-mastercontainer
    restart: unless-stopped
    ports:
      - "127.0.0.1:11000:11000"
      - "127.0.0.1:8080:8080"
    volumes:
      - nextcloud_aio_mastercontainer:/mnt/docker-aio-config
      - /var/run/docker.sock:/var/run/docker.sock:ro
      - /mnt/nas/nextcloud/data:/mnt/nas/nextcloud/data
```

**Gestion**
```bash
# Accès local
https://192.168.129.10:8080
# Logs
docker logs -f nextcloud-aio-mastercontainer
```

### Uptime Kuma

**Installation**
```bash
docker run -d --restart=always -p 3001:3001 -v uptime-kuma:/app/data --name uptime-kuma louislam/uptime-kuma:1
```

**Gestion**
```bash
# Accès
https://192.168.129.10:3001
# Logs
docker logs -f uptime-kuma
```

---

## 🔒 Sécurité

### Pare-feu UFW

**Configuration**
```bash
# Règles actives
ufw status verbose

# Ajouter une règle
ufw allow 8080/tcp

# Supprimer une règle
ufw delete allow 8080/tcp
```

**Règles recommandées**
```bash
ufw default deny incoming
ufw default allow outgoing
ufw allow ssh
ufw allow 8000/tcp  # Coolify
ufw allow 8080/tcp  # Nextcloud
ufw enable
```

### Fail2Ban

**Configuration avancée**
```ini
# /etc/fail2ban/jail.local
[sshd]
enabled = true
maxretry = 5
bantime = 1h
findtime = 10m
ignoreip = 192.168.129.0/24
```

**Gestion**
```bash
# Voir les IPs bannies
fail2ban-client status sshd

# Débannir une IP
fail2ban-client set sshd unbanip 1.2.3.4

# Recharger la configuration
fail2ban-client reload
```

### Bonnes Pratiques

1. **Mises à jour**
   ```bash
   sudo apt update && sudo apt upgrade -y
   sudo apt autoremove
   ```

2. **Permissions**
   ```bash
   chmod 600 ~/.ssh/authorized_keys
   chmod 700 ~/.ssh
   ```

3. **Audit**
   ```bash
   find /home -type f -perm -4000
   last -10
   ```

---

## 🛠️ Procédures Opérationnelles

### Démarrage/Arrêt

**Serveur**
```bash
# Redémarrer
sudo shutdown -r now

# Éteindre
sudo shutdown -h now

# Mettre à jour
sudo apt update && sudo apt upgrade -y && sudo reboot
```

**NAS**
```bash
# Via interface web ou
ssh Steph@192.168.129.21 "sudo shutdown -r now"
```

### Sauvegardes

**Manuelle**
```bash
# Créer une archive
tar -czvf backup-$(date +%Y%m%d).tar.gz /data

# Vers le NAS
rsync -avz /data Steph@192.168.129.21:/volume1/backups/
```

**Automatique**
```bash
# Configurer cron
crontab -e
0 3 * * * /usr/local/bin/backup.sh
```

### Mises à jour

**Serveur**
```bash
sudo apt update
sudo apt upgrade -y
sudo apt autoremove
```

**Containers**
```bash
# Mettre à jour tous les containers
docker-compose pull
docker-compose up -d

# Nettoyer
docker system prune -a
```

---

## 🔧 Dépannage

### Problèmes Courants

#### 1. SSH ne fonctionne pas

**Diagnostic**
```bash
ssh -v user@host
tail -f /var/log/auth.log
```

**Solutions**
```bash
# Vérifier les permissions
ls -la ~/.ssh
chmod 600 ~/.ssh/authorized_keys

# Redémarrer SSH
sudo systemctl restart sshd

# Vérifier la configuration
sudo sshd -t
```

#### 2. Docker ne démarre pas

**Diagnostic**
```bash
systemctl status docker
journalctl -u docker
```

**Solutions**
```bash
# Redémarrer Docker
sudo systemctl restart docker

# Vérifier les logs
docker logs <container>

# Nettoyer
docker system prune
```

#### 3. NFS ne monte pas

**Diagnostic**
```bash
mount | grep nfs
showmount -e 192.168.129.21
tail -f /var/log/syslog
```

**Solutions**
```bash
# Redémarrer NFS
sudo systemctl restart nfs-kernel-server

# Monter manuellement
sudo mount -a

# Vérifier les exports
sudo exportfs -v
```

#### 4. UPS ne répond pas

**Diagnostic**
```bash
upsc eaton
sudo systemctl status nut-server
```

**Solutions**
```bash
# Redémarrer NUT
sudo systemctl restart nut-server

# Tester la connexion USB
lsusb | grep Eaton

# Vérifier les logs
sudo tail -f /var/log/nut/nut.log
```

---

## 📅 Maintenance

### Checklist Mensuelle

- [ ] Vérifier les logs Fail2Ban
- [ ] Mettre à jour les containers Docker
- [ ] Tester la restauration des backups
- [ ] Vérifier l'espace disque
- [ ] Tester l'UPS

```bash
# Espace disque
df -h

# Logs Fail2Ban
sudo fail2ban-client status sshd

# Mises à jour
sudo apt update && sudo apt list --upgradable

# Test UPS
upsc eaton
```

### Checklist Trimestrielle

- [ ] Rotater les clés SSH
- [ ] Tester l'UPS (simulation coupure)
- [ ] Vérifier les performances RAID
- [ ] Mettre à jour la documentation

### Checklist Annuelle

- [ ] Remplacer les batteries UPS
- [ ] Audit complet de sécurité
- [ ] Remplacer les disques durs (si nécessaire)

---

## 📚 Annexes

### Commandes Utiles

**Réseau**
```bash
# Test de connectivité
ping 192.168.129.10
mtr 192.168.129.21

# Test de port
nc -zv 192.168.129.10 22

# Bandwidth
iftop -i eth0
```

**Système**
```bash
# Processus
htop

# Mémoire
free -h

# Disque
df -h
iotop
```

**Docker**
```bash
# Inspecter un container
docker inspect <container>

# Statistiques
docker stats

# Nettoyage
docker system df
```

### Glossaire

| Terme | Définition |
|-------|------------|
| NFS | Network File System - Protocole de partage de fichiers |
| UPS | Uninterruptible Power Supply - Onduleur |
| RAID1 | Redundant Array of Independent Disks - Miroir |
| SSH | Secure Shell - Protocole de connexion sécurisée |
| Docker | Plateforme de conteneurisation |

---

## 🎯 Conclusion

Cette documentation technique couvre l'intégralité de l'infrastructure homelab. Pour toute question ou problème non couvert, consulter :

1. La documentation officielle Ubuntu/UGOS
2. Les logs système (`/var/log/`)
3. Les forums spécialisés
4. Les issues GitHub des projets open-source utilisés

**Dernière mise à jour** : 23 juin 2026
**Version** : 2.0
**Statut** : Document vivant - à mettre à jour régulièrement