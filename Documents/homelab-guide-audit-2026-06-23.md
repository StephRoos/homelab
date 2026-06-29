# Homelab — Guide d'installation complet (Audit 2026-06-23)

> **Audit réalisé le 23 juin 2026** — Documentation mise à jour pour refléter l'état réel du homelab
> **Configuration actuelle :** Ubuntu 24.04.4 LTS · MINISFORUM UM880 Plus · NAS UGREEN · Eaton Ellipse PRO 1600

---

## 00 · État actuel du homelab (post-audit)

### Configuration matérielle réelle

| Composant | Modèle | IP réelle | Notes |
|---|---|---|---|
| Serveur principal | MINISFORUM UM880 Plus | 192.168.129.10 | 32 Go RAM, 1 To NVMe |
| NAS | UGREEN NAS | 192.168.129.21 | 2×4 To RAID 1 (3.7 To utilisable) |
| Switch | TP-Link TL-SG105-M2 | - | 2.5 GbE |
| UPS | Eaton Ellipse PRO 1600 | - | USB connecté au serveur |
| Écran | Dell U3223QE | - | KVM intégré utilisé |

### Configuration logicielle réelle

- **OS :** Ubuntu 24.04.4 LTS (kernel 6.17.0-35-generic)
- **Utilisateur :** steph (sudo configuré)
- **Services actifs :** Docker, Cloudflared, Fail2Ban, NUT
- **Containers principaux :** Coolify, Nextcloud AIO, Uptime Kuma
- **Stockage :** 4 volumes NFS montés depuis le NAS

---

## 01 · Configuration réseau réelle

### Adresses IP réelles

```
Serveur UM880 Plus : 192.168.129.10
NAS UGREEN : 192.168.129.21
Box internet : 192.168.129.1
Sous-réseau : 192.168.129.0/24
```

### Configuration Docker réelle

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

---

## 02 · Montages NFS réels

### Configuration /etc/fstab actuelle

```
192.168.129.21:/volume1/appdata   /mnt/nas/appdata   nfs defaults,_netdev,noexec,nosuid,timeo=30,hard,nofail 0 0
192.168.129.21:/volume1/backups   /mnt/nas/backups   nfs defaults,_netdev,noexec,nosuid,timeo=30,hard,nofail 0 0
192.168.129.21:/volume1/nextcloud /mnt/nas/nextcloud nfs defaults,_netdev,noexec,nosuid,timeo=30,hard,nofail 0 0
192.168.129.21:/volume1/timemachine /mnt/nas/timemachine nfs defaults,_netdev,noexec,nosuid,timeo=30,hard,nofail 0 0
```

---

## 03 · Services système réels

### État des services (23/06/2026)

```bash
# Docker
systemctl status docker
# → active (running) since Wed 2026-06-03

# Cloudflared
systemctl status cloudflared
# → active (running) since Wed 2026-06-03

# Fail2Ban
systemctl status fail2ban
# → active (running) since Wed 2026-06-03

# NUT (UPS)
systemctl status nut-server
# → active (running) since Wed 2026-06-03
```

---

## 04 · Containers Docker actifs

### Liste des containers (23/06/2026)

```
coolify-sentinel: Up 2 weeks
nextcloud-aio-mastercontainer: Up 2 weeks (healthy)
nextcloud-aio-apache: Up 2 weeks (healthy)
forgejo: Up 2 weeks
app-kmpuu3pdcjlbrlpwauy0entm-183902847842: Up About a minute (healthy)
db-kmpuu3pdcjlbrlpwauy0entm-183902843899: Up 2 minutes (healthy)
sync-m8wbq55ie9ghoxo8udx860ke-181048522553: Up 24 hours
api-m8wbq55ie9ghoxo8udx860ke-181048514567: Up 24 hours (healthy)
web-m8wbq55ie9ghoxo8udx860ke-181048519468: Up 24 hours (healthy)
db-m8wbq55ie9ghoxo8udx860ke-181048510683: Up 25 hours (healthy)
```

---

## 05 · Configuration UPS réelle

### État de l'Eaton Ellipse PRO 1600

```bash
upsc eaton
# battery.charge: 100
# battery.charge.low: 20
# device.model: Ellipse PRO 1600
# ups.load: 3
# ups.status: OL (On Line)
```

---

## 06 · Commandes de diagnostic actuelles

### Vérification quotidienne recommandée

```bash
# État système
df -h /mnt/nas/*
free -h
uname -a

# Services
systemctl status docker cloudflared fail2ban nut-server

# Docker
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

# UPS
upsc eaton | grep -E "status|charge|load"

# NFS
mount | grep nfs
df -h | grep nas

# Sécurité
sudo fail2ban-client status sshd
cat /var/log/unattended-upgrades/unattended-upgrades.log | tail -5
```

---

## 07 · Recommandations post-audit

### Actions immédiates

1. **Corriger les IPs** dans toute la documentation pour utiliser 192.168.129.x
2. **Mettre à jour les références** au matériel (UM880 Plus au lieu de UM790 Pro)
3. **Standardiser** le nom d'utilisateur (steph au lieu de admin)
4. **Documenter** la configuration Docker complète avec les pools d'adresses

### Améliorations suggérées

1. **Ajouter un monitoring** plus complet des services
2. **Automatiser les backups** de configuration
3. **Documenter les procédures** de récupération d'urgence
4. **Créer un script** de vérification automatique de l'état du homelab

---

## 08 · Historique des changements

| Date | Changement | Responsable |
|---|---|---|
| 2026-06-23 | Audit complet et documentation mise à jour | Mistral Vibe |
| 2026-06-03 | Installation initiale Ubuntu 24.04 | steph |
| 2026-05-XX | Réception matériel UM880 Plus | steph |

---

**Score audit : A-** (Configuration solide, documentation à mettre à jour pour refléter la réalité)

> Ce document remplace toutes les versions précédentes et doit être considéré comme la référence actuelle.
> Dernière mise à jour : 23 juin 2026