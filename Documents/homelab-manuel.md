---
title: Homelab — Manuel de configuration
date: 2026-04-11
tags: [homelab, infrastructure, reference]
---

# Homelab anthemion.dev — Manuel de configuration

Référence complète de l'installation homelab au 2026-04-11. Source de vérité pour la configuration courante. Les guides `homelab-guide.md` et `homelab-guide-post-audit.md` restent utiles comme procédure d'installation initiale.

## 1. Architecture matérielle

| Composant | Modèle | Rôle |
|---|---|---|
| Serveur | MINISFORUM UM880 Plus (Ryzen 7 8845HS, 32 Go DDR5, 1 To NVMe) | Hôte Docker, services applicatifs |
| NAS | UGREEN (UGOS) | Stockage NFS/SMB, Time Machine, snapshots |
| Switch | TP-Link TL-SG105-M2 (2.5 GbE) | Backbone LAN |
| Onduleur | Eaton Ellipse PRO 1600 FR | Protection électrique, coupure propre |
| Box FAI | Proximus b-box | Gateway, DHCP |

**Câblage switch :**
- Port 1 : UM880
- Port 2 : NAS UGREEN
- Port 3 : b-box Proximus
- Onduleur : UM880 en USB (HID)

## 2. Réseau

Particularité Proximus : DHCP en `192.168.129.0/24`, gateway en `192.168.128.1`.

| Hôte | IP | Notes |
|---|---|---|
| Gateway Proximus | 192.168.128.1 | Accès admin non exposé |
| UM880 (`homelab`) | 192.168.129.10/24 | Statique via netplan |
| NAS UGREEN | 192.168.129.21 | DHCP réservé |
| DNS | 8.8.8.8, 1.1.1.1 | Définis côté netplan |

Alias SSH local (`~/.ssh/config` sur le Mac) :

```
Host homelab
  HostName 192.168.129.10
  User steph
  IdentityFile ~/.ssh/id_ed25519
  ServerAliveInterval 60
  ServerAliveCountMax 3
  SetEnv TERM=xterm-256color
```

Configuration IP statique UM880 — `/etc/netplan/00-installer-config.yaml` :

```yaml
network:
  version: 2
  ethernets:
    enp2s0:
      dhcp4: false
      addresses:
        - 192.168.129.10/24
      routes:
        - to: default
          via: 192.168.128.1
      nameservers:
        addresses: [8.8.8.8, 1.1.1.1]
```

Appliquer : `sudo netplan apply`.

**WiFi (MediaTek MT7902) :** aucun driver Linux stable. À ne jamais utiliser — ethernet uniquement.

## 3. Système — UM880

- OS : **Ubuntu Server 24.04 LTS** (le choix Debian 13 a été abandonné pour cause de conflit nftables/Docker)
- Utilisateur : `steph` (sudo NOPASSWD via `/etc/sudoers.d/steph`)
- Accès SSH : clés ED25519 uniquement (pas de mot de passe)
- Pare-feu : UFW
- Durcissement : Fail2Ban (jail `sshd`), `unattended-upgrades`

Règles UFW actives :

| Port | Service | Source |
|---|---|---|
| 22/tcp | SSH | any |
| 8000/tcp | Coolify UI | any (tunnel uniquement) |
| 8080/tcp | Traefik dashboard | any (tunnel uniquement) |
| 11000/tcp | Nextcloud AIO apache | any (tunnel uniquement) |
| 3493/tcp | NUT upsd | 192.168.129.21 (NAS seulement) |

Note : les ports publics côté internet sont **fermés**. Tout transite par Cloudflare Tunnel.

## 4. Docker

Installé via `get.docker.com`. Configuration — `/etc/docker/daemon.json` :

```json
{
  "log-driver": "json-file",
  "log-opts": {"max-size": "10m", "max-file": "3"},
  "default-address-pools": [{"base": "10.0.0.0/8", "size": 24}],
  "ip": "127.0.0.1"
}
```

Le binding `"ip": "127.0.0.1"` est critique : il empêche Docker d'exposer les ports publiés sur toutes les interfaces. Toute publication explicite doit donc préciser l'interface d'écoute (ex. `-p 127.0.0.1:8181:8080`).

⚠ Coolify a tendance à réécrire `/etc/docker/daemon.json` lors de mises à jour — vérifier la présence du champ `"ip"` après chaque upgrade (voir maintenance).

## 5. Stockage NAS — montages NFS

Partages exportés depuis le NAS UGREEN en NFS v4. Fstab UM880 :

```
192.168.129.21:/volume1/appdata    /mnt/nas/appdata    nfs defaults,_netdev,noexec,nosuid,timeo=30 0 0
192.168.129.21:/volume1/backups    /mnt/nas/backups    nfs defaults,_netdev,noexec,nosuid,timeo=30 0 0
192.168.129.21:/volume1/nextcloud  /mnt/nas/nextcloud  nfs defaults,_netdev,noexec,nosuid,timeo=30 0 0
192.168.129.21:/volume1/timemachine /mnt/nas/timemachine nfs defaults,_netdev,noexec,nosuid,timeo=30 0 0
```

Utilisation :
- `/mnt/nas/nextcloud/data` → données utilisateur Nextcloud AIO
- `/mnt/nas/appdata` → volumes persistants des services Docker
- `/mnt/nas/backups` → destinations de sauvegardes locales (Nextcloud dumps, Coolify)
- `/mnt/nas/timemachine` → partage SMB dédié Time Machine (monté aussi sur NAS pour Samba)

## 6. Services exposés

Publication via **Cloudflare Tunnel** (`cloudflared` en service systemd). Domaine `anthemion.dev` délégué à Cloudflare.

| URL publique | Service interne | Container |
|---|---|---|
| https://coolify.anthemion.dev | http://localhost:8000 | coolify |
| https://uptime.anthemion.dev | http://localhost:80 (Traefik → uptime-kuma) | uptime-kuma |
| https://cloud.anthemion.dev | http://localhost:11000 | nextcloud-aio-apache |

Admin Nextcloud AIO : `http://127.0.0.1:8181` — uniquement via tunnel SSH local :

```
ssh -L 8181:127.0.0.1:8181 homelab
```

## 7. Coolify

- Déployé via installation officielle (`https://coolify.io/`)
- Proxy : Traefik (`coolify-proxy`) écoute 80/443/8080
- Projets :
  - **uptime-kuma** — domaine `https://uptime.anthemion.dev`
- Coolify lui-même est exposé via son propre service systemd + container, tunnel Cloudflare pointant sur `http://localhost:8000`

Stack Docker Coolify : `coolify`, `coolify-proxy`, `coolify-db`, `coolify-redis`, `coolify-realtime`, `coolify-sentinel`.

## 8. Nextcloud All-in-One

Déployé en dehors de Coolify (Coolify ne sait pas gérer la structure master/child de l'AIO). Commande de référence du mastercontainer :

```bash
docker run -d \
  --name nextcloud-aio-mastercontainer \
  --restart unless-stopped \
  -p 127.0.0.1:8181:8080 \
  -e APACHE_PORT=11000 \
  -e APACHE_IP_BINDING=0.0.0.0 \
  -e NEXTCLOUD_DATADIR=/mnt/nas/nextcloud/data \
  -e NEXTCLOUD_STARTUP_APPS='deck tasks calendar contacts notes' \
  -v nextcloud_aio_mastercontainer:/mnt/docker-aio-config \
  -v /var/run/docker.sock:/var/run/docker.sock:ro \
  -v /mnt/nas/nextcloud/data:/mnt/nas/nextcloud/data \
  nextcloud/all-in-one:latest
```

Points critiques :
- **Ne pas publier le port 11000 sur le mastercontainer.** AIO démarre ensuite un container enfant `nextcloud-aio-apache` qui binde lui-même `0.0.0.0:11000`. Dupliquer la publication casse le domaincheck.
- Le port admin `8181` est restreint à `127.0.0.1` — pas d'exposition publique.
- Data : `/mnt/nas/nextcloud/data` (NFS NAS).
- Apps pré-installées : deck, tasks, calendar, contacts, notes.

Containers enfants : `apache`, `nextcloud`, `database` (postgres), `redis`, `imaginary`, `collabora`, `notify-push`.

## 9. Time Machine

Samba configuré sur le NAS (`/etc/samba/smbshare.conf`) :

```
[timemachine]
path                   = /volume1/timemachine
writeable              = yes
valid users            = @admin Steph
write list             = @admin Steph
fruit:time machine     = yes
fruit:time machine max size = 500G
vfs objects            = catia fruit full_audit recycle streams_xattr ug_xattr_filter
```

Publication mDNS Avahi — `/etc/avahi/services/timemachine.service` :

```xml
<?xml version="1.0" standalone="no"?>
<!DOCTYPE service-group SYSTEM "avahi-service.dtd">
<service-group>
  <name replace-wildcards="yes">%h</name>
  <service>
    <type>_adisk._tcp</type>
    <port>9</port>
    <txt-record>sys=waMa=0,adVF=0x100</txt-record>
    <txt-record>dk0=adVN=timemachine,adVF=0x82</txt-record>
  </service>
</service-group>
```

Sans cette publication Avahi, le NAS n'apparaît pas dans les destinations Time Machine de macOS même si le partage SMB est actif.

## 10. Sauvegardes 3-2-1

Trois cibles, deux supports, une copie hors site.

| Cible | Source | Destination | Fréquence |
|---|---|---|---|
| Copie 1 (locale NAS) | données live UM880 | snapshots UGOS Sync | quotidien (UGOS Sync) |
| Copie 2 (disque externe) | NAS | Disque ORICO externe via rsync UGOS Sync | quotidien 10:00 |
| Copie 3 (hors site) | `/mnt/nas/{nextcloud,appdata,backups}` | Backblaze B2 `homelab-backup-anthemion` | quotidien 04:00 |

### Script rclone — `/usr/local/bin/b2-backup.sh`

```bash
#!/bin/bash
LOG=/var/log/rclone-b2-backup.log
echo "$(date): Starting B2 backup" >> $LOG
rclone sync /mnt/nas/nextcloud b2:homelab-backup-anthemion/nextcloud --log-file=$LOG --log-level INFO
rclone sync /mnt/nas/appdata    b2:homelab-backup-anthemion/appdata    --log-file=$LOG --log-level INFO
rclone sync /mnt/nas/backups    b2:homelab-backup-anthemion/backups    --log-file=$LOG --log-level INFO
echo "$(date): B2 backup complete" >> $LOG
```

Cron — `/etc/cron.d/b2-backup` :

```
0 4 * * * root /usr/local/bin/b2-backup.sh
```

Credentials rclone dans `/root/.config/rclone/rclone.conf` (profil `b2`). Bucket B2 avec Object Lock activé.

## 11. Onduleur — NUT

**UM880 = serveur NUT (primary)**. NAS = client NUT (secondary).

### UM880 — serveur NUT

`/etc/nut/ups.conf` :

```ini
[eaton]
  driver = usbhid-ups
  port = auto
  desc = "Eaton Ellipse PRO 1600 FR"
  vendorid = 0463
  productid = ffff
```

`/etc/nut/upsd.conf` :

```
LISTEN 127.0.0.1 3493
LISTEN 192.168.129.10 3493
```

`/etc/nut/upsd.users` :

```
[upsmonitor]
  password = UpsM0n2026!
  upsmon primary

[nasmonitor]
  password = NasM0n2026!
  upsmon secondary
```

`/etc/nut/upsmon.conf` :

```
MONITOR eaton@localhost 1 upsmonitor UpsM0n2026! primary
MINSUPPLIES 1
SHUTDOWNCMD "/sbin/shutdown -h +0"
POLLFREQ 5
POLLFREQALERT 5
HOSTSYNC 15
DEADTIME 15
POWERDOWNFLAG /etc/killpower
```

Règle udev USB — `/etc/udev/rules.d/90-nut-ups.rules` :

```
SUBSYSTEM=="usb", ATTR{idVendor}=="0463", ATTR{idProduct}=="ffff", MODE="0660", GROUP="nut"
```

Mode de service — `/etc/nut/nut.conf` : `MODE=netserver`.

### NAS — client NUT

`/etc/nut/nut.conf` : `MODE=netclient`.

`/etc/nut/upsmon.conf` — ajouter :

```
MONITOR eaton@192.168.129.10 1 nasmonitor NasM0n2026! secondary
```

Vérification : `upsc eaton@192.168.129.10` depuis le NAS doit renvoyer l'état batterie.

## 12. Fichiers de configuration critiques — index

| Fichier | Hôte | Rôle |
|---|---|---|
| `/etc/netplan/00-installer-config.yaml` | UM880 | IP statique |
| `/etc/docker/daemon.json` | UM880 | Binding Docker 127.0.0.1 |
| `/etc/fstab` | UM880 | Montages NFS NAS |
| `/etc/sudoers.d/steph` | UM880 | NOPASSWD |
| `/etc/ufw/*` | UM880 | Pare-feu |
| `/etc/cron.d/b2-backup` | UM880 | Planification sauvegarde B2 |
| `/usr/local/bin/b2-backup.sh` | UM880 | Script rclone |
| `/root/.config/rclone/rclone.conf` | UM880 | Credentials B2 |
| `/etc/nut/*.conf` | UM880 + NAS | NUT |
| `/etc/udev/rules.d/90-nut-ups.rules` | UM880 | Permissions USB onduleur |
| `/etc/cloudflared/config.yml` | UM880 | Tunnel Cloudflare |
| `/etc/samba/smbshare.conf` | NAS | Partage Time Machine |
| `/etc/avahi/services/timemachine.service` | NAS | Publication mDNS Time Machine |

## 13. Secrets et credentials

- Mots de passe NUT : `UpsM0n2026!`, `NasM0n2026!` (locaux, jamais exposés)
- Mot de passe sudo NAS : dans le gestionnaire de mots de passe personnel
- Credentials Backblaze B2 : `/root/.config/rclone/rclone.conf` (lecture root uniquement)
- Token Cloudflare Tunnel : stocké dans `/etc/cloudflared/` après `cloudflared service install`
- Clés SSH : `~/.ssh/id_ed25519` côté Mac, autorisées via `~/.ssh/authorized_keys` côté UM880
- Admin Nextcloud AIO : mot de passe généré une fois à l'initialisation, conservé dans le gestionnaire

Aucun secret ne doit être commité dans SecondBrain en clair. Les rotations sensibles (B2, Cloudflare) passent par le gestionnaire de mots de passe.
