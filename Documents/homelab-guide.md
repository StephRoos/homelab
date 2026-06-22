# Homelab — Guide d'installation complet (post-audit)

> **Mac M4 Pro · MINISFORUM UM880 Plus · NAS UGREEN · Dell U3223QE · Eaton 1600 · Coolify**
> Score audit : B+ → A-

---

## 00 · Matériel reçu & câblage complet

*Inventaire · Avant de brancher quoi que ce soit*

### Vérifier le contenu de la commande

| Article | Qté | Vérification |
|---|---|---|
| MINISFORUM UM880 Plus (32 Go / 1 To) | 1 | Câble alimentation + adaptateur OCuLink inclus dans la boîte |
| TP-Link TL-SG105-M2 | 1 | Bloc d'alimentation DC inclus |
| UGREEN USB-C → RJ45 2.5G | 1 | Adaptateur seul, pas de câble |
| Belkin Thunderbolt 5 USB-C 1m | 1 | Câble Mac → Dell (vidéo + hub + charge) |
| PremiumCord USB-A → USB-C 1m | 1 | UM880 → port upstream #8 Dell (KVM) |
| Amazon Basics HDMI 2.0 0,9m | 1 | UM880 → entrée HDMI Dell |
| deleyCON 10× Cat6 0,5m | 10 | Câbles réseau courts pour le coin serveur |

> Le câble USB de l'Eaton Ellipse PRO 1600 est inclus dans la boîte de l'onduleur. Le câble USB-C du Dell U3223QE est fourni avec l'écran. Ces deux câbles n'ont pas besoin d'être commandés.

> **Note UM880 Plus :** Le UM880 Plus est équipé d'un port OCuLink natif (PCIe 4.0 x4) pour connecter un eGPU externe. L'adaptateur OCuLink est inclus dans la boîte et utilise un des deux slots M.2 2280. La RAM est en SO-DIMM DDR5-5600 (32 Go par défaut, extensible à 96 Go). Le Ryzen 7 8845HS intègre un iGPU Radeon 780M (RDNA 3, 12 CU) capable de faire tourner des modèles ML en inférence locale via Ollama.

### Plan de câblage définitif

**Coin bureau — Mac mini + Dell U3223QE**
- Mac mini M4 Pro ── Belkin TB5 USB-C 1m ──→ Dell U3223QE port USB-C #5 `[vidéo 4K + hub + 90W]`
- Clavier + Souris ── USB-A (existants) ──→ Ports USB-A downstream du Dell `[suivent le KVM]`
- Mac mini ── WiFi 6E ──→ Box internet `[pas de câble réseau au bureau]`

**Coin serveur — UM880 Plus + NAS + Switch + Box + Eaton**
- UM880 Plus ── HDMI 0,9m ──→ Dell entrée HDMI `[KVM — image serveur]`
- UM880 Plus ── PremiumCord USB-A→C 1m ──→ Dell port USB-C upstream #8 `[KVM — clavier/souris]`
- UM880 Plus ── Cat6 0,5m ──→ Switch port 1 `[réseau 2.5 Gbps]`
- NAS UGREEN ── Cat6 0,5m ──→ Switch port 2 `[réseau 2.5 Gbps]`
- Box internet ── Cat6 0,5m ──→ Switch port 3 `[WAN vers internet]`
- UM880 Plus ── câble USB Eaton (fourni) ──→ Port USB de l'Eaton 1600 `[NUT — arrêt auto]`

**Alimentation Eaton Ellipse PRO 1600 (8 prises FR)**
- Prises batterie (4) : UM880 Plus · NAS UGREEN · Switch · Box internet
- Prises surge only (4) : Mac mini · Dell U3223QE · libres

> ⚠ Le câble HDMI (UM880 → Dell) sera utilisé pendant l'installation de Debian avec le UM880 posé temporairement sur le bureau. Après installation et déplacement dans le coin serveur, ce câble reste branché de façon permanente pour le KVM.

---

## 01 · Configurer le KVM du Dell

*À faire en premier · KVM intégré Dell U3223QE · Un seul écran pour Mac + UM880 · Sans boîte externe*

### Brancher le Mac mini sur le Dell (câble principal) `Mac`

Le Dell U3223QE a un KVM intégré. Il gère deux PC sur un seul écran avec un seul clavier et une seule souris — sans KVM externe. La connexion principale se fait via un seul câble USB-C.

1. Brancher le câble **Belkin Thunderbolt 5 USB-C 1m** : port Thunderbolt 5 arrière du Mac mini → port USB-C **#5** du Dell (marqué USB-C + DP). Ce câble transporte vidéo 4K, hub USB et charge 90W.
2. Brancher clavier et souris sur les ports **USB-A downstream** du Dell (ports #9 ou #10 à l'arrière). Ils suivront automatiquement le KVM.
3. Allumer le Dell. L'écran doit afficher le bureau macOS. Si rien n'apparaît, appuyer sur le joystick → Input Source → USB-C.
4. Sur le Mac, aller dans Réglages système → Affichages → vérifier la résolution : doit être 3840×2160 (4K).

### Brancher le UM880 Plus sur le Dell (KVM deuxième source) `UM880`

1. Brancher le câble **HDMI 0,9m** : port HDMI du UM880 → entrée **HDMI** du Dell. C'est la vidéo du serveur.
2. Brancher le câble **PremiumCord USB-A → USB-C 1m** : port USB-A du UM880 → port USB-C upstream **#8** du Dell (données uniquement, pas vidéo). C'est le lien KVM pour clavier/souris.
3. Sans ce câble USB-A→C, l'écran affiche bien le UM880 mais le clavier et la souris restent sur le Mac — ne pas oublier.

### Configurer le KVM dans Dell Display Manager `Mac`

Dell Display Manager (DDM) est une application gratuite qui permet de configurer le KVM avec des raccourcis clavier.

1. Télécharger **Dell Display Manager pour macOS** sur dell.com/support → chercher "DDM macOS U3223QE".
2. Installer et ouvrir DDM → onglet **Input Manager** → **KVM Wizard**.
3. Sélectionner 2 PC → PC1 : USB-C + USB-C upstream → PC2 : HDMI + USB-C upstream #8.
4. Assigner un raccourci clavier — ex: `Ctrl+Ctrl` ou utiliser le joystick de l'écran (appui long).
5. Tester : appuyer sur le raccourci → l'écran bascule du Mac vers le UM880.

> ⚠ Si le signal vidéo disparaît au retour sur le Mac après un switch, attendre 3-4 secondes que le Mac re-handshake avec l'EDID du Dell. C'est normal au premier branchement.

---

## 02 · Switch 2.5 GbE & IPs fixes

*Réseau local · Coin serveur · TP-Link TL-SG105-M2 · IPs réservées · Mac en WiFi*

### Brancher le switch et les câbles réseau `Matériel`

1. Placer le TP-Link TL-SG105-M2 dans le coin serveur, à côté de la box, du NAS et de l'Eaton.
2. Cat6 0,5m : switch port 1 → port RJ45 du UM880 Plus (2.5 Gbps natif).
3. Cat6 0,5m : switch port 2 → port RJ45 du NAS UGREEN (2.5 Gbps natif).
4. Cat6 0,5m : switch port 3 → port LAN de la box internet.
5. Brancher l'alimentation du switch → les LEDs s'allument. LED verte = 2.5 Gbps, orange = 1 Gbps.

> Le Mac reste en WiFi 6E. Pas de câble réseau au bureau. Le Dell U3223QE a un port RJ45 intégré mais il est optionnel pour l'instant — le laisser débranché.

### Réserver les IPs dans l'interface de la box `Box`

Accéder à l'interface de la box (généralement http://192.168.128.1) pour fixer des IPs statiques à chaque machine.

1. Interface box → DHCP → Baux statiques (ou "Réservations" selon le modèle de box).
2. Trouver l'adresse MAC du UM880 Plus (visible dans l'interface box une fois branché) → lui assigner **192.168.128.10**.
3. Même chose pour le NAS UGREEN → **192.168.129.21**.
4. Sauvegarder et redémarrer les équipements si nécessaire.
5. Vérifier depuis le Mac : `ping 192.168.128.10` et `ping 192.168.129.21` → doivent répondre.

---

## 03 · Installation Ubuntu Server 24.04 LTS sur le UM880 Plus

*Serveur principal · ~30 min · UM880 temporairement au bureau · Clé USB bootable · BIOS · Install minimale · SSH vérifié · Déplacement final*

> **Pourquoi Ubuntu et pas Debian ?** Debian 13 utilise nftables comme backend firewall. Docker y manipule les règles nftables et bloque tout le trafic entrant après chaque reboot — même avec `iptables: false` dans daemon.json. Ubuntu 24.04 LTS utilise une couche de compatibilité iptables-nft que Docker connaît parfaitement. Pas de conflit, pas de configuration supplémentaire. C'est la plateforme de référence pour Docker en production.

### Créer la clé USB bootable Ubuntu 24.04 LTS (depuis le Mac) `Mac`

Ubuntu Server 24.04 LTS est supporté jusqu'en 2029 (standard) et 2034 (extended). C'est la version à utiliser.

1. Télécharger **Ubuntu Server 24.04 LTS** (~2.5 Go) : **ubuntu.com/download/server** → choisir "Ubuntu Server 24.04 LTS" → télécharger l'ISO amd64.
2. Télécharger Balena Etcher (Mac) : **etcher.balena.io** → installer et ouvrir.
3. Insérer une clé USB ≥ 8 Go dans le Mac → Etcher → Flash from file → sélectionner le .iso → Select target → clé USB → Flash.
4. Attendre la fin du flash (~5-8 min). La clé est prête.

### Poser le UM880 Plus temporairement sur le bureau `UM880`

Le UM880 sera installé avec l'écran Dell pendant ~30 min, puis déplacé dans le coin serveur une fois Ubuntu installé et SSH configuré.

1. Poser le UM880 Plus sur le bureau à côté du Dell. Brancher : câble HDMI 0,9m → entrée HDMI Dell, câble USB-A→C → port upstream #8 Dell, câble réseau Cat6 → switch, et alimentation.
2. Sur le Dell, switcher l'entrée sur HDMI (joystick → Input Source → HDMI).
3. Insérer la clé USB dans le UM880 Plus.

### Configurer le BIOS et booter sur la clé `UM880`

1. Allumer le UM880 et appuyer immédiatement sur `DEL` ou `F2` pour entrer dans le BIOS.
2. Dans le BIOS : Security → Secure Boot → **Disabled**. Sauvegarder.
3. Redémarrer → appuyer sur `F7` ou `F11` → sélectionner la clé USB dans le boot menu.
4. L'écran Ubuntu apparaît → choisir **"Try or Install Ubuntu Server"**.

### Installer Ubuntu Server 24.04 LTS — étapes complètes `UM880`

L'installeur Ubuntu (Subiquity) est un TUI moderne avec navigation à la souris ou aux flèches.

1. **Langue :** English (recommandé pour les logs et la doc technique — laisser en anglais).
2. **Clavier :** Belgian (ou French) → Done.
3. **Type d'install :** Ubuntu Server (pas minimized) → Done.
4. **Réseau :** l'interface `enp2s0` doit déjà avoir une IP DHCP. On configurera le statique après — laisser pour l'instant → Done.
5. **Proxy :** laisser vide → Done.
6. **Mirror :** laisser le miroir Ubuntu par défaut → Done.
7. **Disque :** Use an entire disk → sélectionner le NVMe (~1 To, `nvme0n1`) → Set up this disk as an LVM group (laisser coché) → Done → confirmer "Continue" pour écraser le disque.
8. **Profil :**
   - Your name : `Steph`
   - Server name : `homelab`
   - Username : `steph`
   - Password : choisir un mot de passe fort
9. **Ubuntu Pro :** Skip for now.
10. **SSH :** cocher **Install OpenSSH server** → Done. Pas besoin d'importer de clé ici, on le fera depuis le Mac.
11. **Snaps :** ne rien cocher → Done.
12. Attendre la fin de l'installation → **Reboot Now** → retirer la clé USB quand demandé.

### Configurer l'IP statique via Netplan `UM880 (sur écran)`

Ubuntu utilise **Netplan** pour la configuration réseau (fichiers YAML dans `/etc/netplan/`). C'est plus lisible et fiable que `/etc/network/interfaces`.

Se connecter en local (écran + clavier) avec `steph` / mot de passe choisi pendant l'install :

```bash
# Voir le fichier netplan existant
ls /etc/netplan/
# → 00-installer-config.yaml

# Éditer la config réseau
sudo nano /etc/netplan/00-installer-config.yaml
```

Remplacer le contenu par :

```yaml
network:
  version: 2
  ethernets:
    enp2s0:
      dhcp4: false
      addresses:
        - 192.168.128.10/24
      routes:
        - to: default
          via: 192.168.128.1
      nameservers:
        addresses: [8.8.8.8, 1.1.1.1]
```

```bash
# Appliquer la configuration
sudo netplan apply

# Vérifier l'IP
ip addr show enp2s0
# → inet 192.168.128.10/24

# Tester la connectivité
ping -c 3 8.8.8.8
```

### Configurer SSH par clé et vérifier la connexion sans mot de passe `Mac`

```bash
# Copier la clé publique sur le UM880
ssh-copy-id steph@192.168.128.10

# Créer ou vérifier l'alias SSH sur le Mac
nano ~/.ssh/config
```

```
Host homelab
  HostName 192.168.128.10
  User steph
  IdentityFile ~/.ssh/id_ed25519
  ServerAliveInterval 60
  ServerAliveCountMax 3
  SetEnv TERM=xterm-256color
```

```bash
ssh homelab
# → connexion immédiate sans mot de passe
```

> Ne passer à l'étape suivante que si `ssh homelab` se connecte sans mot de passe.

### Sécuriser SSH et configurer UFW `UM880 (via SSH)`

```bash
# Désactiver l'auth par mot de passe SSH
sudo nano /etc/ssh/sshd_config
# Modifier :
# PermitRootLogin no
# PasswordAuthentication no

sudo systemctl restart ssh

# Vérifier immédiatement depuis un autre onglet Terminal
# ssh homelab → doit fonctionner

# Configurer UFW
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow ssh
sudo ufw allow 8000/tcp    # Coolify
sudo ufw allow 8080/tcp    # Nextcloud AIO
sudo ufw enable
sudo ufw status verbose
```

### Déplacer le UM880 Plus dans le coin serveur `UM880`

SSH sans mot de passe ✓ · PermitRootLogin no ✓ · UFW actif ✓. Le UM880 peut maintenant être déplacé définitivement.

1. Éteindre proprement : `sudo shutdown -h now` depuis le Mac via SSH.
2. Débrancher du bureau : HDMI Dell, USB-A→C Dell, câble réseau, alimentation.
3. Installer dans le coin serveur : câble réseau Cat6 → switch port 1, alimentation → prise batterie Eaton.
4. Rallumer → depuis le Mac : `ssh homelab` → doit se connecter. C'est le seul test nécessaire.

---

## 04 · Outils système & hardening 🛡

*Depuis le Mac uniquement · SSH headless · Fail2Ban · Mises à jour auto · Docker sécurisé*

### Vérifier l'état du système `UM880 (via SSH)`

Depuis ce point, toutes les commandes se font via `ssh homelab` depuis le Mac. L'utilisateur `steph` a déjà sudo configuré par Ubuntu.

```bash
# Vérifier l'état du système
uname -a
# → Linux homelab 6.8.x ... x86_64 GNU/Linux (kernel Ubuntu 24.04)
df -h /
# → ~1 To disponible sur nvme0n1
free -h
# → ~30 Go RAM disponible
ip addr show enp2s0
# → 192.168.128.10 sur l'interface RJ45

# Mise à jour complète
sudo apt update && sudo apt upgrade -y
```

### Installer Fail2Ban — protection brute-force SSH `UM880 (root)` 🛡

> 🛡 **Recommandation audit — Priorité haute.** Même avec les clés SSH, un brute-force sur le port 22 consomme des ressources et remplit les logs. Fail2Ban bannit automatiquement les IPs offensantes après 5 tentatives.

```bash
# Installer Fail2Ban
sudo apt install -y fail2ban

# Le jail SSH est activé par défaut sur Debian 13
# Vérifier que le service tourne
sudo systemctl enable --now fail2ban
sudo fail2ban-client status sshd
# → doit afficher : Number of jail: 1 · Jail list: sshd
# → Currently banned: 0 (normal au début)
```

### Activer les mises à jour de sécurité automatiques `UM880 (root)` 🛡

> 🛡 **Recommandation audit — Priorité haute.** Un serveur headless 24/7 doit appliquer les patches de sécurité sans intervention manuelle.

```bash
# Installer et configurer
sudo apt install -y unattended-upgrades apt-listchanges

# Activer automatiquement
sudo dpkg-reconfigure -plow unattended-upgrades
# → Sélectionner "Yes" quand demandé

# Vérifier la configuration
cat /etc/apt/apt.conf.d/20auto-upgrades
# → APT::Periodic::Update-Package-Lists "1";
# → APT::Periodic::Unattended-Upgrade "1";

# Tester un dry-run
sudo unattended-upgrades --dry-run --debug
# → doit se terminer sans erreur
```

### Installer Docker et configurer le binding `UM880 (root)` 🛡

> **Ubuntu 24.04 et Docker :** pas de conflit nftables. Docker s'installe et fonctionne après reboot sans configuration particulière du firewall.

> 🛡 **Recommandation audit — Priorité haute.** Par défaut, Docker publie les ports sur 0.0.0.0 (toutes les interfaces). Forcer le binding sur 127.0.0.1 empêche tout accès externe non voulu. Cloudflare Tunnel accède via localhost, donc aucun impact.

```bash
# Installer Docker via le script officiel
curl -fsSL https://get.docker.com | sudo sh

# Ajouter steph au groupe docker
sudo usermod -aG docker steph

# Déconnecter et reconnecter SSH pour que le groupe soit effectif
exit
ssh homelab

# Configurer Docker pour lier les ports à 127.0.0.1
sudo nano /etc/docker/daemon.json
```

```json
{
  "ip": "127.0.0.1",
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  }
}
```

```bash
sudo systemctl restart docker

# Vérifier que Docker fonctionne
docker run --rm hello-world
# → "Hello from Docker!"

# Vérifier que Docker écoute bien sur 127.0.0.1
docker run --rm -d -p 8888:80 --name test-bind nginx
ss -tlnp | grep 8888
# → doit afficher 127.0.0.1:8888, PAS 0.0.0.0:8888
docker stop test-bind

# Rebooter et vérifier que SSH répond toujours
sudo reboot
# Attendre ~30 secondes puis :
ssh homelab && echo "OK — Docker ne casse pas le réseau"
```

> Ce réglage global s'applique à tous les futurs containers. Cloudflare Tunnel se connecte à localhost. Plus besoin de spécifier `127.0.0.1:` dans chaque docker-compose.

---

## 05 · NAS UGREEN — RAID 1 & montage NFS

*Stockage · UGOS Pro · RAID 1 · Boîtier ORICO en JBOD · NFS sécurisé sur UM880*

### Configurer le RAID 1 dans UGOS Pro `NAS`

Accéder à UGOS Pro depuis le Mac : http://192.168.129.21 ou via l'app UGREEN NASSync. Avec 2 disques internes de 4 To → RAID 1 = 4 To utilisables avec redondance complète.

1. Storage Manager → Create Storage Pool → sélectionner les **2 disques internes** → **RAID 1** (miroir). Avec 2 × 4 To → 4 To utilisables.
2. Créer un Volume sur ce pool → nom : `data` → tout l'espace disponible.
3. File Station → créer les dossiers partagés : `appdata` · `backups` · `nextcloud` · `timemachine`.
4. Control Panel → File Services → **NFS** → Enable.
5. Control Panel → File Services → **SMB** → Enable (pour Time Machine).
6. Pour chaque dossier partagé → Propriétés → Permissions NFS → autoriser 192.168.129.10 (UM880) en lecture/écriture.

> ⚠ RAID 1 protège contre la panne d'un disque. Quand tu ajouteras un 3ème disque, UGOS Pro permet de migrer un pool RAID 1 vers RAID 5 sans recréer de zéro et sans perte de données.

### Monter le NAS sur le UM880 via NFS `UM880 (root)`

```bash
apt install -y nfs-common

# Créer les points de montage
mkdir -p /mnt/nas/{appdata,backups,nextcloud,timemachine}

# Tester le montage
mount -t nfs 192.168.129.21:/volume1/appdata /mnt/nas/appdata
df -h | grep nas
umount /mnt/nas/appdata

# Rendre les montages permanents dans fstab
# Options noexec,nosuid = sécurité (correction audit)
nano /etc/fstab
```

Ajouter ces 4 lignes dans `/etc/fstab` :

```
192.168.129.21:/volume1/appdata   /mnt/nas/appdata   nfs defaults,_netdev,noexec,nosuid,timeo=30 0 0
192.168.129.21:/volume1/backups   /mnt/nas/backups   nfs defaults,_netdev,noexec,nosuid,timeo=30 0 0
192.168.129.21:/volume1/nextcloud /mnt/nas/nextcloud nfs defaults,_netdev,noexec,nosuid,timeo=30 0 0
192.168.129.21:/volume1/timemachine /mnt/nas/timemachine nfs defaults,_netdev,noexec,nosuid,timeo=30 0 0
```

```bash
mount -a
df -h | grep nas
# → les 4 volumes doivent apparaître montés
```

---

## 06 · Installation Coolify

*Déploiement apps · ~15 min · Une commande · Docker auto · Traefik · Uptime Kuma*

### Installer Coolify `UM880 (root)`

```bash
curl -fsSL https://cdn.coollabs.io/coolify/install.sh | bash
# ~5-10 min. Docker installé automatiquement.
# À la fin : accès sur http://192.168.128.10:8000
```

1. Depuis le Mac : ouvrir http://192.168.128.10:8000 → créer le compte admin (premier compte = admin automatiquement).
2. Settings → Instance URL → `https://coolify.tondomain.com` · Email Let's Encrypt → ton email.
3. Sources → Add → GitHub App → OAuth → autoriser tes repos.
4. Déployer **Uptime Kuma** immédiatement : Add Resource → Docker Image → `louislam/uptime-kuma` → Port 3001 → Deploy.

### Accès SSH tunnel vers Coolify (accès local sécurisé) `Mac`

Coolify tourne sur le port 8000 en local. Pour y accéder depuis Safari sans l'exposer sur internet, utiliser un tunnel SSH.

```bash
ssh -L 8000:localhost:8000 homelab -N &
# Ouvrir http://localhost:8000 dans Safari
# Pour arrêter le tunnel : kill %1
```

---

## 07 · Cloudflare & DNS

*Accès internet · Domaine · Nameservers · Wildcard DNS · SSL strict*

### Configurer Cloudflare sur ton domaine `Cloudflare`

1. cloudflare.com → créer un compte → Add a Site → entrer ton domaine.
2. Choisir le plan gratuit → Cloudflare affiche deux nameservers.
3. Chez ton registrar (OVH, Namecheap...) → changer les nameservers pour ceux de Cloudflare → sauvegarder.
4. Attendre 5-30 min → Cloudflare indiquera "Active" une fois la propagation terminée.
5. SSL/TLS → Mode → **Full (strict)** → activer.

> Les records DNS seront gérés automatiquement par le Cloudflare Tunnel (phase 08) — ne pas créer de records A manuellement.

---

## 08 · Cloudflare Tunnel

*Zéro port ouvert · IP résidentielle cachée · cloudflared en service · Zero Trust · Routes par sous-domaine*

### Créer le tunnel dans Cloudflare Zero Trust `Cloudflare`

1. Aller sur **one.dash.cloudflare.com** → sélectionner ton compte → Networks → Tunnels.
2. Create a tunnel → Cloudflared → nommer le tunnel : **homelab**.
3. Cloudflare génère un token. **Copier ce token** — il sera utilisé à l'étape suivante.

### Installer cloudflared sur le UM880 `UM880 (root)`

```bash
# Télécharger et installer cloudflared
curl -L https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb -o cloudflared.deb
dpkg -i cloudflared.deb
cloudflared --version

# Installer en service systemd avec le token
# Remplacer TON_TOKEN par le token copié depuis Cloudflare
cloudflared service install TON_TOKEN_ICI
systemctl enable --now cloudflared
systemctl status cloudflared
# → doit afficher : active (running)
```

> Dans Cloudflare Zero Trust → Tunnels → le tunnel "homelab" doit afficher le statut **HEALTHY** (point vert).

### Configurer les routes publiques (Public Hostnames) `Cloudflare`

Zero Trust → Tunnels → homelab → Configure → Public Hostname → Add a public hostname.

1. **coolify**.tondomain.com → Service : `http://localhost:8000`
2. **cloud**.tondomain.com → Service : `http://localhost:11000` (Nextcloud)
3. **status**.tondomain.com → Service : `http://localhost:3001` (Uptime Kuma)
4. Pour chaque app déployée via Coolify : ajouter une route supplémentaire.
5. Cloudflare crée automatiquement les records CNAME dans le DNS → pas de gestion manuelle.
6. Supprimer le port forwarding 80/443 sur la box s'il existe · Supprimer règles ufw 80/tcp et 443/tcp si présentes.

---

## 09 · Déployer une app depuis GitHub

*Premier déploiement · Push → live en moins de 5 min · PostgreSQL · Webhooks auto*

### Créer projet et déployer depuis GitHub `Coolify`

1. http://192.168.128.10:8000 → Projects → New Project → donner un nom.
2. Add Resource → Application → GitHub → sélectionner le repo → branche main.
3. Build Pack auto-détecté (Next.js, Node, Python...) · Domain : **app.tondomain.com**.
4. Deploy → suivre les logs en temps réel. Premier build : 2-5 min. Les suivants sont plus rapides (cache Docker).
5. Coolify configure le webhook GitHub automatiquement → chaque push = redéploiement.
6. Ajouter la route dans Cloudflare Tunnel : **app**.tondomain.com → `http://localhost:PORT`.

---

## 10 · Nextcloud AIO — via Coolify

*Souveraineté · Remplacement Google · Fichiers · Calendrier · Contacts · Photos · Collabora Office*

### Préparer les volumes NAS pour Nextcloud `NAS + UM880`

```bash
# Créer les sous-dossiers Nextcloud sur le NAS
mkdir -p /mnt/nas/nextcloud/{data,config}
# www-data = user nginx dans le container Nextcloud
chown -R 33:33 /mnt/nas/nextcloud
chmod -R 755 /mnt/nas/nextcloud

# Vérifier
ls -la /mnt/nas/nextcloud
```

### Déployer Nextcloud AIO via Coolify `Nextcloud`

1. Coolify → Projects → New Project → nom : **nextcloud**.
2. Add Resource → Docker Compose → coller le compose ci-dessous.
3. Deploy → attendre 3-5 min.

```yaml
version: '3.8'
services:
  nextcloud-aio-mastercontainer:
    image: nextcloud/all-in-one:latest
    container_name: nextcloud-aio-mastercontainer
    restart: unless-stopped
    ports:
      - "127.0.0.1:11000:11000"  # audit: bind localhost only
      - "127.0.0.1:8080:8080"    # audit: bind localhost only
    environment:
      - APACHE_PORT=11000
      - APACHE_IP_BINDING=0.0.0.0
      - NEXTCLOUD_DATADIR=/mnt/nas/nextcloud/data
      - NEXTCLOUD_STARTUP_APPS=deck tasks calendar contacts notes
    volumes:
      - nextcloud_aio_mastercontainer:/mnt/docker-aio-config
      - /var/run/docker.sock:/var/run/docker.sock:ro
      - /mnt/nas/nextcloud/data:/mnt/nas/nextcloud/data
volumes:
  nextcloud_aio_mastercontainer:
    name: nextcloud_aio_mastercontainer
```

### Premier démarrage et configuration AIO `Nextcloud`

1. Ouvrir https://192.168.128.10:8080 depuis le Mac (accès local). Accepter le certificat auto-signé.
2. AIO affiche un mot de passe initial → le noter soigneusement.
3. Saisir le domaine : **cloud.tondomain.com** → AIO vérifie que le tunnel répond (le tunnel doit être actif).
4. Activer les modules : **Collabora** (suite bureautique) · **Talk** (visio/chat) · **Imaginary** (prévisualisations) · **Clamav** (antivirus).
5. Cliquer **Start containers** → AIO télécharge et démarre tout (~10 min).
6. Une fois tous les containers verts → **Open your Nextcloud** → https://cloud.tondomain.com → créer le compte admin.

### Synchroniser Mac, iPhone et appareils `Clients`

1. **Mac — Fichiers :** télécharger Nextcloud Desktop sur nextcloud.com/install → se connecter → `https://cloud.tondomain.com` → sync automatique.
2. **Mac — Calendrier :** Réglages système → Internet Accounts → Ajouter → Autre → Compte CalDAV → URL : `https://cloud.tondomain.com/remote.php/dav` · identifiants Nextcloud.
3. **Mac — Contacts :** même démarche avec CardDAV → même URL.
4. **iPhone :** app Nextcloud (App Store) → se connecter → activer la sauvegarde photos automatique.
5. **iPhone — Calendrier/Contacts :** Réglages → Mail → Comptes → Ajouter → Autre → CalDAV / CardDAV → même URL.

> Calendrier, contacts et fichiers synchronisés sur tous tes appareils via ton propre serveur. Zéro Google, zéro iCloud pour ces données.

---

## 11 · Time Machine + Hyper Backup + Backblaze B2

*Backup · Règle 3-2-1 · Automatique · RAID 1 NAS · ORICO RAID 1 permanent · Hyper Backup nightly · B2 hors-site · AES-256*

### Activer Time Machine → NAS `Mac`

1. Sur UGOS → dossier "timemachine" → activer l'option **Time Machine backup** dans les propriétés du partage SMB.
2. Sur le Mac → Réglages système → Général → Time Machine → Ajouter un disque de sauvegarde → Réseau → UGREEN NAS → timemachine.
3. S'authentifier avec l'utilisateur NAS → activer.
4. Premier backup : brancher l'adaptateur UGREEN USB-C → RJ45 2.5G sur le Mac — beaucoup plus rapide que WiFi pour le premier backup complet.

### Configurer Hyper Backup → boîtier ORICO (backup nightly local) `NAS`

Le boîtier ORICO dual-bay est en RAID 1 (1 To utilisable, miroir interne automatique). Il reste branché en permanence sur le NAS.

1. UGOS Pro → **Hyper Backup** → Create → **Local folder & USB**.
2. Destination : sélectionner le **boîtier ORICO** (volume de 1 To).
3. Dossiers à sauvegarder : cocher **appdata** · **nextcloud** · **timemachine** · **backups**.
4. Activer **Client-side encryption** → définir un mot de passe fort → le noter dans ton gestionnaire de mots de passe. Sans lui, le backup est illisible.
5. Planification : tous les jours à **3h00**.
6. Rétention : **30 versions** → 30 jours de rétention.
7. Lancer le premier backup manuellement → surveiller la progression → vérifier que le job se termine sans erreur.

### Configurer Hyper Backup → Backblaze B2 (backup hors-site automatique) `NAS + B2`

> Backblaze B2 couvre le sinistre physique (incendie, vol). C'est la pièce hors-site de la règle 3-2-1 — automatique, sans manipulation, ~1€/mois pour 100 Go.

1. Créer un compte sur **backblaze.com** → B2 Cloud Storage → Create Bucket → nom : `homelab-backup` → Private → activer **Object Lock** (optionnel).
2. App Keys → Create Application Key → accès limité au bucket `homelab-backup` → noter le **keyID** et **applicationKey** (affichés une seule fois).
3. UGOS Pro → Hyper Backup → Create → **B2 Cloud Storage**.
4. Saisir le keyID et applicationKey → sélectionner le bucket `homelab-backup`.
5. Mêmes dossiers que le job local : **appdata** · **nextcloud** · **backups**. Exclure **timemachine** (trop volumineux pour B2, déjà couvert localement).
6. Activer **Client-side encryption** → utiliser le **même mot de passe** que le job ORICO pour simplifier.
7. Planification : tous les jours à **4h00** (après le job ORICO de 3h).
8. Premier backup → sera plus long (upload selon ta connexion). Les suivants sont incrémentiels et rapides.

> **Règle 3-2-1 complète et 100% automatique :** Copie 1 : RAID 1 NAS (données en temps réel) · Copie 2 : ORICO RAID 1 via Hyper Backup (versionné, local, nightly) · Copie 3 : Backblaze B2 (hors-site, chiffré, automatique, ~1€/mois). Zéro manipulation manuelle.

### Tester la restauration des backups (local + B2) `NAS` 🛡

> 🛡 **Recommandation audit — Priorité haute.** Un backup non testé n'est pas un backup. Valider l'intégrité de chaque job en restaurant un fichier test. À refaire mensuellement.

1. UGOS Pro → Hyper Backup → sélectionner le **job ORICO** → Restore → choisir un fichier ou dossier test → restaurer vers un emplacement temporaire.
2. Vérifier que le fichier restauré est intact et lisible. Comparer avec l'original.
3. Faire la même chose pour le **job Backblaze B2** → Restore → fichier test → vérifier l'intégrité.
4. Supprimer les fichiers de test restaurés une fois la validation terminée.
5. Mettre un **rappel mensuel** (dans Nextcloud Calendar) pour refaire ce test régulièrement.

> Les deux jobs de restauration fonctionnent ✓ — la règle 3-2-1 est validée de bout en bout.

---

## 12 · UPS & NUT — arrêt automatique

*Sécurité électrique · Eaton Ellipse PRO 1600 FR · ~110W de charge · NUT 2.8 · driver usbhid-ups · netserver*

### Câbler l'Eaton Ellipse PRO 1600 `UPS`

Charge estimée : UM880 ~35W + NAS ~45W + switch ~8W + box ~15W = **~103W** sur 1000W disponibles (~10%). Autonomie estimée : **40 à 55 minutes** à cette charge.

**Prises "Battery + Surge" (4 prises secourues)**
- UM880 Plus ──→ Prise 1 `[secouru batterie]`
- NAS UGREEN ──→ Prise 2 `[secouru batterie]`
- Switch TP-Link ──→ Prise 3 `[secouru batterie]`
- Box internet ──→ Prise 4 `[secouru batterie]`

**Prises "Surge only" (4 prises protection surtension)**
- Mac mini M4 Pro ──→ Prise 5 `[surge only — batterie interne Mac]`
- Dell U3223QE ──→ Prise 6 `[surge only]`

**Communication USB**
- Port USB Eaton ──→ Port USB-A du UM880 `[câble fourni avec l'Eaton · NUT lit l'état batterie]`

### Installer et configurer NUT `UM880 (root)`

Driver confirmé pour l'Eaton Ellipse PRO 1600 : **usbhid-ups** avec vendorID `0463` productID `ffff` (validé NUT 2.8.0).

```bash
apt install -y nut nut-client

# Vérifier que l'UPS est détecté
lsusb | grep -i "0463\|MGE\|Eaton"
# → Bus 001 Device 0XX: ID 0463:ffff MGE UPS Systems UPS

# Scanner pour confirmation
nut-scanner -U
# → driver="usbhid-ups" vendorid="0463" productid="ffff"
```

`/etc/nut/ups.conf` :
```ini
[eaton]
  driver = usbhid-ups
  port = auto
  desc = "Eaton Ellipse PRO 1600 FR"
  vendorid = 0463
  productid = ffff
  maxretry = 3
```

`/etc/nut/nut.conf` :
```
MODE=netserver
```

`/etc/nut/upsd.conf` :
```
LISTEN 127.0.0.1 3493
LISTEN 192.168.128.10 3493
```

`/etc/nut/upsd.users` — utiliser de vrais mots de passe :
```ini
[upsmonitor]
  password = MOT_DE_PASSE_FORT_1
  upsmon primary

[nasmonitor]
  password = MOT_DE_PASSE_FORT_2
  upsmon secondary
```

`/etc/nut/upsmon.conf` :
```
MONITOR eaton@localhost 1 upsmonitor MOT_DE_PASSE_FORT_1 primary
MINSUPPLIES 1
SHUTDOWNCMD "/sbin/shutdown -h +0"
POLLFREQ 5
POLLFREQALERT 5
HOSTSYNC 15
DEADTIME 15
POWERDOWNFLAG /etc/killpower
FINALDELAY 5
```

```bash
systemctl enable --now nut-server nut-monitor nut-driver-enumerator
upsdrvctl start
upsc eaton
# Valeurs attendues :
# ups.status: OL        ← On Line = sur secteur
# battery.charge: 100
# ups.load: 10          ← ~10% de charge
# device.model: Ellipse PRO 1600

# Autoriser le NAS à se connecter au serveur NUT
ufw allow from 192.168.129.21 to any port 3493
```

### Configurer le NAS UGREEN comme client NUT `NAS`

UGOS Pro a un client NUT intégré. Quand l'UPS est sur batterie et que le niveau descend, le NAS s'arrête proprement avant extinction.

1. UGOS Pro → Control Panel → Hardware → UPS.
2. Sélectionner **Network UPS** (pas USB).
3. Adresse du serveur NUT : `192.168.128.10`.
4. Nom UPS : `eaton` · Utilisateur : `nasmonitor` · Mot de passe : configuré dans upsd.users.
5. Délai avant arrêt : 120 secondes · Appliquer.

---

## 13 · Vérification — tout fonctionne

*Validation complète · Checklist finale · Homelab production-ready · Stack souveraine · Sécurité électrique*

### Checklist de validation complète

- [ ] **KVM Dell :** switch Mac ↔ UM880 avec raccourci clavier. Écran bascule en moins de 3 secondes.
- [ ] **SSH :** `ssh homelab` depuis Mac → connexion immédiate sans mot de passe.
- [ ] **Réseau :** `ping 192.168.128.10` (UM880) et `ping 192.168.129.21` (NAS) répondent depuis le Mac.
- [ ] **NFS :** `df -h | grep nas` → les 4 volumes NAS montés sur le UM880.
- [ ] **Coolify :** http://192.168.128.10:8000 accessible · GitHub connecté · premier déploiement réussi.
- [ ] **Tunnel :** `systemctl status cloudflared` → active (running) · Cloudflare Zero Trust → HEALTHY.
- [ ] **Nextcloud :** https://cloud.tondomain.com accessible · calendrier synchro Mac · photos iPhone sauvegardées.
- [ ] **Time Machine :** Réglages système → Time Machine → sauvegarde active · premier backup en cours.
- [ ] **UPS :** `upsc eaton | grep status` → `ups.status: OL` · NAS configuré en client NUT.
- [ ] **Sécurité SSH :** `ssh root@192.168.128.10` → doit être refusé (PermitRootLogin no).
- [ ] **Uptime Kuma :** https://status.tondomain.com → surveille tous les services · alertes configurées.
- [ ] **Hyper Backup local :** job ORICO actif → premier backup terminé sans erreur · chiffrement AES-256 activé · planification 3h00.
- [ ] **Hyper Backup B2 :** job Backblaze B2 actif → premier upload terminé · planification 4h00 · bucket `homelab-backup` visible sur backblaze.com.
- [ ] **Test restauration :** un fichier restauré avec succès depuis le job ORICO ET depuis le job B2.

**Checks sécurité 🛡 :**

- [ ] 🛡 **Fail2Ban :** `sudo fail2ban-client status sshd` → jail active · 0 banned (ou plus).
- [ ] 🛡 **Unattended-upgrades :** `cat /etc/apt/apt.conf.d/20auto-upgrades` → Update "1" · Unattended-Upgrade "1".
- [ ] 🛡 **Docker binding :** `cat /etc/docker/daemon.json` → `"ip": "127.0.0.1"` · Aucun port Docker sur 0.0.0.0.
- [ ] 🛡 **NFS sécurisé :** `mount | grep nfs` → options noexec,nosuid présentes sur chaque montage.

> 🏠 Homelab production-ready et durci. Stack souveraine complète. Sécurité électrique assurée. Hardening validé (Fail2Ban + auto-upgrades + Docker 127.0.0.1). Score audit : A-.

### Commandes de diagnostic quotidiennes

```bash
# État UPS
upsc eaton | grep -E "status|charge|runtime|load"

# État des containers Docker
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

# État du tunnel Cloudflare
systemctl status cloudflared --no-pager

# Utilisation disque NAS
df -h /mnt/nas/*

# Logs Coolify en temps réel
docker logs -f coolify --tail 50

# Vérifier les montages NFS
mount | grep nfs

# État Fail2Ban (audit)
sudo fail2ban-client status sshd

# Vérifier Docker binding (audit)
ss -tlnp | grep docker

# Dernières mises à jour automatiques (audit)
cat /var/log/unattended-upgrades/unattended-upgrades.log | tail -20

# Utilisation CPU/RAM/réseau
htop
```
