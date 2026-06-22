---
title: "Homelab — Guide d'installation complet (post-audit)"
tags: [homelab, guide, infrastructure, serveur, audit, securite]
---

# Homelab — Guide d'installation complet (post-audit)

> **Note (2026-04-19)** : Les IPs réelles du réseau sont sur le sous-réseau `192.168.129.x` (pas `192.168.1.x` comme dans le guide initial). UM790 = `192.168.129.10` (user `steph`, SSH alias `homelab`), NAS = `192.168.129.21` (user `Steph`). Adapter les commandes en conséquence.

## 00 - Matériel reçu & câblage complet
*Inventaire · Avant de brancher quoi que ce soit*
Vérifier la commande · Identifier chaque câble · Plan de branchement

### Vérifier le contenu de la commande `Inventaire`

| Article | Quantité | Vérification |
| --- | --- | --- |
| UM790 Pro (32 Go / 1 To) | 1 | Câble alimentation + câble HDMI inclus dans la boîte |
| TP-Link TL-SG105-M2 | 1 | Bloc d'alimentation DC inclus |
| UGREEN USB-C → RJ45 2.5G | 1 | Adaptateur seul, pas de câble |
| Belkin Thunderbolt 5 USB-C 1m | 1 | Câble Mac → Dell (vidéo + hub + charge) |
| PremiumCord USB-A → USB-C 1m | 1 | UM790 → port upstream #8 Dell (KVM) |
| Amazon Basics HDMI 2.0 0,9m | 1 | UM790 → entrée HDMI Dell |
| deleyCON 10× Cat6 0,5m | 10 | Câbles réseau courts pour le coin serveur |

> Le câble USB de l'Eaton Ellipse PRO 1600 est inclus dans la boîte de l'onduleur. Le câble USB-C du Dell U3223QE est fourni avec l'écran. Ces deux câbles n'ont pas besoin d'être commandés.

### Plan de câblage définitif `Câblage`

```
Coin bureau — Mac mini + Dell U3223QE
 Mac mini M4 Pro ── Belkin TB5 USB-C 1m ──→ Dell U3223QE port USB-C #5 [vidéo 4K + hub + 90W]
 Clavier + Souris ── USB-A (existants) ──→ Ports USB-A downstream du Dell [suivent le KVM]
 Mac mini ── WiFi 6E ──→ Box internet [pas de câble réseau au bureau]

 Coin serveur — UM790 + NAS + Switch + Box + Eaton
 UM790 Pro ── HDMI 0,9m ──→ Dell entrée HDMI [KVM — image serveur]
 UM790 Pro ── PremiumCord USB-A→C 1m ──→ Dell port USB-C upstream #8 [KVM — clavier/souris]
 UM790 Pro ── Cat6 0,5m ──→ Switch port 1 [réseau 2.5 Gbps]
 NAS UGREEN ── Cat6 0,5m ──→ Switch port 2 [réseau 2.5 Gbps]
 Box internet ── Cat6 0,5m ──→ Switch port 3 [WAN vers internet]
 UM790 Pro ── câble USB Eaton (fourni) ──→ Port USB de l'Eaton 1600 [NUT — arrêt auto]

 Alimentation Eaton Ellipse PRO 1600 (8 prises FR)
 Prises batterie (4) : UM790 · NAS UGREEN · Switch · Box internet
 Prises surge only (4) : Mac mini · Dell U3223QE · libres
```

> **Attention** : Le câble HDMI (UM790 → Dell) sera utilisé pendant l'installation de Debian avec le UM790 posé temporairement sur le bureau. Après installation et déplacement du UM790 dans le coin serveur, ce câble reste branché de façon permanente pour le KVM.


## 01 - Configurer le KVM du Dell
*À faire en premier · KVM intégré **Dell U3223QE***
Un seul écran pour Mac + UM790 · Sans boîte externe · Dell Display Manager

### Brancher le Mac mini sur le Dell (câble principal) `Mac`

> Le Dell U3223QE a un KVM intégré. Il gère deux PC sur un seul écran avec un seul clavier et une seule souris — sans KVM externe. La connexion principale se fait via un seul câble USB-C.

- 1. Brancher le câble **Belkin Thunderbolt 5 USB-C 1m** : port Thunderbolt 5 arrière du Mac mini → port USB-C **#5** du Dell (marqué avec le symbole USB-C + DP). Ce câble transporte vidéo 4K, hub USB et charge 90W.
- 2. Brancher clavier et souris sur les ports **USB-A downstream** du Dell (ports #9 ou #10 à l'arrière). Ils suivront automatiquement le KVM.
- 3. Allumer le Dell. L'écran doit afficher le bureau macOS. Si rien n'apparaît, appuyer sur le joystick de l'écran → Input Source → USB-C.
- 4. Sur le Mac, aller dans Réglages système → Affichages → vérifier la résolution : doit être 3840×2160 (4K). Si pas le cas, sélectionner manuellement.

### Brancher le UM790 sur le Dell (KVM deuxième source) `UM790`

- 1. Brancher le câble **HDMI 0,9m** : port HDMI du UM790 → entrée **HDMI** du Dell. C'est la vidéo du serveur.
- 2. Brancher le câble **PremiumCord USB-A → USB-C 1m** : port USB-A du UM790 → port USB-C upstream **#8** du Dell (marqué "USB-C upstream", données uniquement, pas vidéo). C'est le lien KVM pour clavier/souris.
- 3. Sans ce câble USB-A→C, l'écran affiche bien le UM790 mais le clavier et la souris restent sur le Mac — ne pas oublier.

### Configurer le KVM dans Dell Display Manager `Mac`

> Dell Display Manager (DDM) est une application gratuite qui permet de configurer le KVM avec des raccourcis clavier et de basculer d'une source à l'autre proprement.

- 1. Télécharger **Dell Display Manager pour macOS** sur dell.com/support → chercher "DDM macOS U3223QE".
- 2. Installer et ouvrir DDM → onglet **Input Manager** → **KVM Wizard**.
- 3. Sélectionner 2 PC → PC1 : USB-C + USB-C upstream → PC2 : HDMI + USB-C upstream #8.
- 4. Assigner un raccourci clavier pour switcher — ex: `Ctrl`+`Ctrl` ou utiliser le joystick de l'écran (appui long).
- 5. Tester : appuyer sur le raccourci → l'écran bascule du Mac vers le UM790 (qui ne tourne pas encore, mais la source change).

> **Attention** : Si le signal vidéo disparaît au retour sur le Mac après un switch, attendre 3-4 secondes que le Mac re-handshake avec l'EDID du Dell. C'est normal au premier branchement.


## 02 - Switch 2.5 GbE & IPs fixes
*Réseau local · Coin serveur*
TP-Link TL-SG105-M2 · IPs réservées · Mac en WiFi

### Brancher le switch et les câbles réseau `Matériel`

- 1. Placer le TP-Link TL-SG105-M2 dans le coin serveur, à côté de la box, du NAS et de l'Eaton.
- 2. Cat6 0,5m : switch port 1 → port RJ45 du UM790 (2.5 Gbps natif).
- 3. Cat6 0,5m : switch port 2 → port RJ45 du NAS UGREEN (2.5 Gbps natif).
- 4. Cat6 0,5m : switch port 3 → port LAN de la box internet.
- 5. Brancher l'alimentation du switch → les LEDs s'allument. LED verte = 2.5 Gbps, orange = 1 Gbps.

> Le Mac reste en WiFi 6E. Pas de câble réseau au bureau. Le Dell U3223QE a un port RJ45 intégré mais il est optionnel pour l'instant — le laisser débranché.

### Réserver les IPs dans l'interface de la box `Box`

> Accéder à l'interface de la box (généralement http://192.168.1.1) pour fixer des IPs statiques à chaque machine. Ainsi elles gardent toujours la même adresse même après un redémarrage.

- 1. Interface box → DHCP → Baux statiques (ou "Réservations" selon le modèle de box).
- 2. Trouver l'adresse MAC du UM790 (visible dans l'interface box une fois branché) → lui assigner **192.168.1.10**.
- 3. Même chose pour le NAS UGREEN → **192.168.1.11**.
- 4. Sauvegarder et redémarrer les équipements si nécessaire.
- 5. Vérifier depuis le Mac : `ping 192.168.1.10` et `ping 192.168.1.11` → doivent répondre.


## 03 - Installation Debian 13 Trixie sur le UM790 Pro
*Serveur principal · ~45 min · UM790 temporairement au bureau*
Clé USB bootable · BIOS · Install minimale · SSH vérifié · Déplacement final

### Créer la clé USB bootable Debian 13 Trixie (depuis le Mac) `Mac`

> Debian 13 "Trixie" est la version stable actuelle (sortie le 9 août 2025, dernière mise à jour 13.4 du 14 mars 2026). C'est la version à utiliser.

- 1. Télécharger Debian 13 "Trixie" netinst (~700 Mo) : **debian.org/distrib/netinst** → choisir **amd64**. Vérifier que le nom du fichier contient bien "trixie" ou "debian-13".
- 2. Télécharger Balena Etcher (Mac) : **etcher.balena.io** → installer et ouvrir.
- 3. Insérer une clé USB ≥ 8 Go dans le Mac → Etcher → Flash from file → sélectionner le .iso → Select target → clé USB → Flash.
- 4. Attendre la fin du flash (~3-5 min). La clé est prête.

### Poser le UM790 temporairement sur le bureau `UM790`

> **Note** : Le UM790 sera installé avec l'écran Dell pendant ~30 min, puis déplacé dans le coin serveur une fois Debian installé et SSH configuré. C'est pourquoi on s'est passé d'un câble HDMI long.

- 1. Poser le UM790 sur le bureau à côté du Dell. Brancher : câble HDMI 0,9m → entrée HDMI Dell, câble USB-A→C → port upstream #8 Dell, câble réseau Cat6 vers switch (avec rallonge si besoin) ou configurer le WiFi pendant l'install, et alimentation.
- 2. Sur le Dell, switcher l'entrée sur HDMI (joystick → Input Source → HDMI).
- 3. Insérer la clé USB dans le UM790.

### Configurer le BIOS et booter sur la clé `UM790`

- 1. Allumer le UM790 et appuyer immédiatement sur `DEL` ou `F2` pour entrer dans le BIOS.
- 2. Dans le BIOS : Security → Secure Boot → **Disabled**. Sauvegarder.
- 3. Redémarrer → appuyer sur `F7` ou `F11` → sélectionner la clé USB dans le boot menu.
- 4. L'écran Debian apparaît → choisir **Install** (pas Graphical install).

### Installer Debian 13 Trixie — étapes complètes `UM790`

- 1. **Langue :** Français → **Pays :** Belgique → **Clavier :** Belge (ou Français selon ta préférence).
- 2. **Réseau :** si câble branché → détection auto. Si WiFi → sélectionner ton réseau + mot de passe.
- 3. **Nom de machine :** `homelab` · **Domaine :** laisser vide.
- 4. **Mot de passe root :** choisir un mot de passe fort et le noter. **Utilisateur :** créer `admin` avec son propre mot de passe.
- 5. **Partitionnement :** Guidé → utiliser tout le disque → sélectionner le **premier NVMe** (généralement nvme0n1, ~1 To) → Tout dans une seule partition → Terminer le partitionnement.
- 6. **Miroir APT :** choisir Belgique → deb.debian.org.
- 7. **Logiciels à installer :** décocher TOUT sauf **"Utilitaires usuels du système"** et **"Serveur SSH"**. Pas d'environnement graphique — serveur headless.
- 8. **GRUB :** installer sur le disque principal → /dev/nvme0n1.
- 9. Redémarrer → retirer la clé USB quand demandé → le serveur démarre sur Debian.

### Première connexion SSH et mise à jour (UM790 encore au bureau) `Mac mini`

> **Note** : Le UM790 est encore au bureau. C'est maintenant qu'on configure et vérifie SSH — **avant** de le déplacer. Une fois dans le coin serveur, on n'aura plus d'écran ni de clavier.

**Terminal — Mac mini**
```bash
# Connexion initiale avec mot de passe
ssh admin@192.168.1.10

# Passer root
su -

# Mise à jour complète Debian 13
apt update && apt upgrade -y

# Outils essentiels
apt install -y curl wget git htop nano ufw net-tools sudo
```

### Configurer SSH par clé et vérifier la connexion sans mot de passe `Mac mini`

**Terminal Mac — nouvel onglet**
```bash
# Générer une clé SSH si pas encore fait
ssh-keygen -t ed25519 -C "homelab-mac"
# Appuyer Entrée pour le chemin par défaut
# Pour la passphrase : Entrée 2 fois (sans passphrase)
# OU entrer une passphrase forte (recommandé par l'audit sécurité)

# Copier la clé publique sur le UM790
ssh-copy-id admin@192.168.1.10

# Créer l'alias SSH
nano ~/.ssh/config
```

**~/.ssh/config**
```
Host homelab
 HostName 192.168.1.10
 User admin
 IdentityFile ~/.ssh/id_ed25519
 ServerAliveInterval 60
 ServerAliveCountMax 3
```

**Vérifier — connexion sans mot de passe**
```bash
ssh homelab
# → connexion immédiate sans mot de passe
# Si ça fonctionne : on peut continuer
# Si ça demande un mot de passe : ne pas déplacer le UM790 avant résolution
```

> Ne passer à l'étape suivante que si `ssh homelab` se connecte sans mot de passe. C'est le critère de validation avant de déplacer la machine.

> **Note** : 🛡 **Recommandation audit :** si tu as choisi une passphrase, ajoute-la au trousseau macOS pour ne plus jamais la retaper : `ssh-add --apple-use-keychain ~/.ssh/id_ed25519`. Transparence totale au quotidien, sécurité renforcée si le Mac est compromis.

### Sécuriser SSH et configurer UFW (UM790 encore au bureau) `UM790 (root)`

> **Attention** : Désactiver l'authentification par mot de passe APRÈS avoir vérifié que la clé SSH fonctionne. Dans le mauvais ordre, on se coupe l'accès.

**SSH — UM790 (root)**
```bash
# Sécuriser SSH
nano /etc/ssh/sshd_config
# Modifier ces lignes :
PermitRootLogin no
PasswordAuthentication no
PubkeyAuthentication yes
AuthorizedKeysFile .ssh/authorized_keys

systemctl restart ssh

# Vérifier immédiatement depuis le Mac (autre onglet Terminal)
# ssh homelab → doit toujours fonctionner
# ssh root@192.168.1.10 → doit être refusé

# Configurer UFW
ufw default deny incoming
ufw default allow outgoing
ufw allow ssh
ufw allow 8000/tcp # Coolify (accès local)
ufw allow 8080/tcp # Nextcloud AIO (local)
ufw enable
ufw status verbose
```

### Déplacer le UM790 dans le coin serveur `UM790`

> SSH fonctionne sans mot de passe ✓ · PermitRootLogin no ✓ · UFW actif ✓. Le UM790 peut maintenant être déplacé définitivement dans le coin serveur — plus besoin d'écran ni de clavier.

- 1. Éteindre proprement : `sudo shutdown -h now` depuis le Mac via SSH, ou depuis la console.
- 2. Débrancher du bureau : HDMI Dell, USB-A→C Dell, câble réseau temporaire, alimentation.
- 3. Installer dans le coin serveur : câble réseau Cat6 0,5m → switch port 1, alimentation → prise batterie de l'Eaton.
- 4. Rebrancher le câble HDMI 0,9m → entrée HDMI du Dell (pour le KVM).
- 5. Rebrancher le câble USB-A→C → port upstream #8 du Dell (pour le KVM clavier/souris).
- 6. Rallumer le UM790 → depuis le Mac : `ssh homelab` → doit se connecter. C'est le seul test nécessaire.

> **Attention** : Si le câble HDMI 0,9m est trop court depuis le coin serveur, le débrancher sans souci — le UM790 fonctionne parfaitement headless. Le KVM ne servira que rarement après cette étape.


## 04 - Outils système, sudo & hardening
*Depuis le Mac uniquement · SSH headless*
Sudo pour admin · Fail2Ban · Mises à jour auto · Docker sécurisé · Prêt pour la suite

### Configurer sudo et vérifier l'installation `UM790 (via SSH)`

> Depuis ce point, toutes les commandes se font via `ssh homelab` depuis le Mac. L'écran Dell et le KVM ne sont plus nécessaires sauf urgence.

**SSH homelab — configurer sudo**
```bash
# Ajouter admin au groupe sudo (en root)
su -
usermod -aG sudo admin
exit

# Vérifier depuis admin
sudo apt update
# → doit fonctionner sans erreur de permission

# Vérifier l'état du système
uname -a
# → Linux homelab 6.12.x ... x86_64 GNU/Linux (kernel Debian 13)
df -h /
# → ~1 To disponible sur nvme0n1
free -h
# → ~30 Go RAM disponible
ip addr show
# → 192.168.1.10 sur l'interface RJ45
```

### Installer Fail2Ban — protection brute-force SSH `UM790 (root)`

> **Recommandation audit** : 🛡 **Recommandation audit — Priorité haute.** Même avec les clés SSH, un brute-force sur le port 22 consomme des ressources et remplit les logs. Fail2Ban bannit automatiquement les IPs offensantes après 5 tentatives.

**SSH — UM790 (root) · Fail2Ban**
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

### Activer les mises à jour de sécurité automatiques `UM790 (root)`

> **Recommandation audit** : 🛡 **Recommandation audit — Priorité haute.** Un serveur headless 24/7 doit appliquer les patches de sécurité sans intervention manuelle. unattended-upgrades installe automatiquement les mises à jour critiques.

**SSH — UM790 (root) · unattended-upgrades**
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

### Configurer Docker pour lier les ports à 127.0.0.1 `UM790 (root)`

> **Recommandation audit** : 🛡 **Recommandation audit — Priorité haute.** Par défaut, Docker publie les ports sur 0.0.0.0 (toutes les interfaces) et manipule iptables directement — il peut bypasser UFW. Forcer le binding sur 127.0.0.1 empêche tout accès externe non voulu. Cloudflare Tunnel accède via localhost, donc aucun impact.

**SSH — UM790 (root) · Docker daemon config**
```bash
# Créer ou éditer le fichier de configuration Docker
sudo nano /etc/docker/daemon.json
```

**/etc/docker/daemon.json**
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

**Appliquer la configuration**
```bash
sudo systemctl restart docker

# Vérifier que Docker écoute bien sur 127.0.0.1
docker run --rm -d -p 8888:80 --name test-bind nginx
ss -tlnp | grep 8888
# → doit afficher 127.0.0.1:8888, PAS 0.0.0.0:8888
docker stop test-bind
```

> Ce réglage global s'applique à tous les futurs containers. Les containers existants (Coolify, Uptime Kuma, Nextcloud) continueront de fonctionner car Cloudflare Tunnel se connecte à localhost. Plus besoin de spécifier `127.0.0.1:` dans chaque docker-compose.


## 05 - NAS UGREEN — RAID 1 & montage NFS
*Stockage · NAS UGREEN*
UGOS Pro · RAID 1 · Boîtier ORICO en JBOD · NFS sécurisé sur UM790

### Configurer le RAID 1 dans UGOS Pro `NAS`

> Accéder à UGOS Pro depuis le Mac : http://192.168.1.11 ou via l'app UGREEN NASSync. Avec 2 disques internes de 4 To → RAID 1 = 4 To utilisables avec redondance complète.

- 1. Storage Manager → Create Storage Pool → sélectionner les **2 disques internes** → **RAID 1** (miroir). Avec 2 × 4 To → 4 To utilisables.
- 2. Créer un Volume sur ce pool → nom : `data` → tout l'espace disponible.
- 3. File Station → créer les dossiers partagés : `appdata` · `backups` · `nextcloud` · `timemachine`.
- 4. Control Panel → File Services → **NFS** → Enable.
- 5. Control Panel → File Services → **SMB** → Enable (pour Time Machine).
- 6. Pour chaque dossier partagé → Propriétés → Permissions NFS → autoriser 192.168.1.10 (UM790) en lecture/écriture.

> **Attention** : RAID 1 protège contre la panne d'un disque. Quand tu ajouteras un 3ème disque, UGOS Pro permet de migrer un pool RAID 1 vers RAID 5 sans recréer de zéro et sans perte de données.

### Monter le NAS sur le UM790 via NFS `UM790 (root)`

**SSH — UM790 (root)**
```bash
apt install -y nfs-common

# Créer les points de montage
mkdir -p /mnt/nas/{appdata,backups,nextcloud,timemachine}

# Tester le montage
mount -t nfs 192.168.1.11:/volume1/appdata /mnt/nas/appdata
df -h | grep nas
umount /mnt/nas/appdata

# Rendre les montages permanents dans fstab
# Options noexec,nosuid = sécurité (correction audit)
nano /etc/fstab
```

**/etc/fstab — ajouter ces 4 lignes**
```ini
192.168.1.11:/volume1/appdata /mnt/nas/appdata nfs defaults,_netdev,noexec,nosuid,timeo=30 0 0
192.168.1.11:/volume1/backups /mnt/nas/backups nfs defaults,_netdev,noexec,nosuid,timeo=30 0 0
192.168.1.11:/volume1/nextcloud /mnt/nas/nextcloud nfs defaults,_netdev,noexec,nosuid,timeo=30 0 0
192.168.1.11:/volume1/timemachine /mnt/nas/timemachine nfs defaults,_netdev,noexec,nosuid,timeo=30 0 0
```

**Tester le montage automatique**
```bash
mount -a
df -h | grep nas
# → les 4 volumes doivent apparaître montés
```


## 06 - Installation Coolify
*Déploiement apps · ~15 min*
Une commande · Docker auto · Traefik · Uptime Kuma

### Installer Coolify `UM790 (root)`

**SSH — UM790 (root)**
```bash
curl -fsSL https://cdn.coollabs.io/coolify/install.sh | bash
# ~5-10 min. Docker installé automatiquement.
# À la fin : accès sur http://192.168.1.10:8000
```

- 1. Depuis le Mac : ouvrir http://192.168.1.10:8000 → créer le compte admin (premier compte = admin automatiquement).
- 2. Settings → Instance URL → `https://coolify.tondomain.com` · Email Let's Encrypt → ton email.
- 3. Sources → Add → GitHub App → OAuth → autoriser tes repos.
- 4. Déployer **Uptime Kuma** immédiatement : Add Resource → Docker Image → `louislam/uptime-kuma` → Port 3001 → Deploy. Surveille tous tes services et envoie des alertes.

### Accès SSH tunnel vers Coolify (accès local sécurisé) `Mac mini`

> Coolify tourne sur le port 8000 en local. Pour y accéder depuis Safari sans l'exposer sur internet, utiliser un tunnel SSH.

**Terminal Mac — tunnel SSH vers Coolify**
```bash
ssh -L 8000:localhost:8000 homelab -N &
# Ouvrir http://localhost:8000 dans Safari
# Pour arrêter le tunnel : kill %1
```


## 07 - Cloudflare & DNS
*Accès internet*
Domaine · Nameservers · Wildcard DNS · SSL strict

### Configurer Cloudflare sur ton domaine `Cloudflare`

- 1. cloudflare.com → créer un compte → Add a Site → entrer ton domaine.
- 2. Choisir le plan gratuit → Cloudflare affiche deux nameservers (ex: `ns1.cloudflare.com`).
- 3. Chez ton registrar (OVH, Namecheap...) → changer les nameservers pour ceux de Cloudflare → sauvegarder.
- 4. Attendre 5-30 min → Cloudflare indiquera "Active" une fois la propagation terminée.
- 5. SSL/TLS → Mode → **Full (strict)** → activer.

> **Note** : Les records DNS seront gérés automatiquement par le Cloudflare Tunnel (phase 08) — ne pas créer de records A manuellement pour les sous-domaines des apps.


## 08 - Cloudflare Tunnel
*Zéro port ouvert · IP résidentielle cachée*
cloudflared en service · Zero Trust · Routes par sous-domaine

### Créer le tunnel dans Cloudflare Zero Trust `Cloudflare`

- 1. Aller sur **one.dash.cloudflare.com** → sélectionner ton compte → Networks → Tunnels.
- 2. Create a tunnel → Cloudflared → nommer le tunnel : **homelab**.
- 3. Cloudflare génère un token. **Copier ce token** — il sera utilisé à l'étape suivante.

### Installer cloudflared sur le UM790 `UM790 (root)`

**SSH — UM790 (root)**
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

> Dans Cloudflare Zero Trust → Tunnels → le tunnel "homelab" doit afficher le statut **HEALTHY** (point vert). Si c'est le cas, cloudflared est bien connecté.

### Configurer les routes publiques (Public Hostnames) `Cloudflare`

> Zero Trust → Tunnels → homelab → Configure → Public Hostname → Add a public hostname.

- 1. **coolify**.tondomain.com → Service : `http://localhost:8000`
- 2. **cloud**.tondomain.com → Service : `http://localhost:11000` (Nextcloud)
- 3. **status**.tondomain.com → Service : `http://localhost:3001` (Uptime Kuma)
- 4. Pour chaque app déployée via Coolify : ajouter une route supplémentaire.
- 5. Cloudflare crée automatiquement les records CNAME dans le DNS → pas de gestion manuelle.
- 6. Supprimer le port forwarding 80/443 sur la box s'il existe · Supprimer règles ufw 80/tcp et 443/tcp si présentes.


## 09 - Déployer une app depuis GitHub
*Premier déploiement*
Push → live en moins de 5 min · PostgreSQL · Webhooks auto

### Créer projet et déployer depuis GitHub `Coolify`

- 1. http://192.168.1.10:8000 → Projects → New Project → donner un nom.
- 2. Add Resource → Application → GitHub → sélectionner le repo → branche main.
- 3. Build Pack auto-détecté (Next.js, Node, Python...) · Domain : **app.tondomain.com**.
- 4. Deploy → suivre les logs en temps réel. Premier build : 2-5 min. Les suivants sont plus rapides (cache Docker).
- 5. Coolify configure le webhook GitHub automatiquement → chaque push = redéploiement.
- 6. Ajouter la route dans Cloudflare Tunnel : **app**.tondomain.com → `http://localhost:PORT`.


## 10 - Nextcloud AIO — via Coolify
*Souveraineté · Remplacement Google*
Fichiers · Calendrier · Contacts · Photos · Collabora Office

### Préparer les volumes NAS pour Nextcloud `NAS + UM790`

**SSH — UM790 (root)**
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

- 1. Coolify → Projects → New Project → nom : **nextcloud**.
- 2. Add Resource → Docker Compose → coller le compose ci-dessous.
- 3. Deploy → attendre 3-5 min.

**docker-compose.yml — Nextcloud AIO**
```yaml
version: '3.8'
services:
 nextcloud-aio-mastercontainer:
 image: nextcloud/all-in-one:latest
 container_name: nextcloud-aio-mastercontainer
 restart: unless-stopped
 ports:
 - "127.0.0.1:11000:11000" # audit: bind localhost only
 - "127.0.0.1:8080:8080" # audit: bind localhost only
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

- 1. Ouvrir https://192.168.1.10:8080 depuis le Mac (accès local). Accepter le certificat auto-signé.
- 2. AIO affiche un mot de passe initial → le noter soigneusement.
- 3. Saisir le domaine : **cloud.tondomain.com** → AIO vérifie que le tunnel répond (le tunnel doit être actif).
- 4. Activer les modules : **Collabora** (suite bureautique) · **Talk** (visio/chat) · **Imaginary** (prévisualisations) · **Clamav** (antivirus).
- 5. Cliquer **Start containers** → AIO télécharge et démarre tout (~10 min).
- 6. Une fois tous les containers verts → **Open your Nextcloud** → https://cloud.tondomain.com → créer le compte admin.

### Synchroniser Mac, iPhone et appareils `Clients`

- 1. **Mac — Fichiers :** télécharger Nextcloud Desktop sur nextcloud.com/install → se connecter → `https://cloud.tondomain.com` → sync automatique du dossier Nextcloud.
- 2. **Mac — Calendrier :** Réglages système → Internet Accounts → Ajouter → Autre → Compte CalDAV → URL : `https://cloud.tondomain.com/remote.php/dav` · identifiants Nextcloud.
- 3. **Mac — Contacts :** même démarche avec CardDAV → même URL.
- 4. **iPhone :** app Nextcloud (App Store) → se connecter → activer la sauvegarde photos automatique.
- 5. **iPhone — Calendrier/Contacts :** Réglages → Mail → Comptes → Ajouter → Autre → CalDAV / CardDAV → même URL.

> Calendrier, contacts et fichiers synchronisés sur tous tes appareils via ton propre serveur. Zéro Google, zéro iCloud pour ces données.


## 11 - Time Machine + Hyper Backup + Backblaze B2
*Backup · Règle 3-2-1 · Automatique*
RAID 1 NAS · ORICO RAID 1 permanent · Hyper Backup nightly · B2 hors-site · AES-256

### Activer Time Machine → NAS `Mac mini`

- 1. Sur UGOS → dossier "timemachine" → activer l'option **Time Machine backup** dans les propriétés du partage SMB.
- 2. Sur le Mac → Réglages système → Général → Time Machine → Ajouter un disque de sauvegarde → Réseau → UGREEN NAS → timemachine.
- 3. S'authentifier avec l'utilisateur NAS → activer.
- 4. Premier backup : brancher l'adaptateur UGREEN USB-C → RJ45 2.5G sur le Mac — beaucoup plus rapide que WiFi pour le premier backup complet.

### Configurer Hyper Backup → boîtier ORICO (backup nightly local) `NAS`

> Le boîtier ORICO dual-bay est en RAID 1 (1 To utilisable, miroir interne automatique). Il reste branché en permanence sur le NAS. Hyper Backup y fait un backup versionné chiffré chaque nuit — si tu supprimes accidentellement un fichier, tu peux remonter jusqu'à 30 jours en arrière.

- 1. UGOS Pro → **Hyper Backup** → Create → **Local folder & USB**.
- 2. Destination : sélectionner le **boîtier ORICO** (volume de 1 To).
- 3. Dossiers à sauvegarder : cocher **appdata** · **nextcloud** · **timemachine** · **backups**.
- 4. Activer **Client-side encryption** → définir un mot de passe fort → le noter dans ton gestionnaire de mots de passe (Bitwarden, 1Password). Sans lui, le backup est illisible.
- 5. Planification : tous les jours à **3h00**.
- 6. Rétention : **30 versions** → 30 jours de rétention.
- 7. Lancer le premier backup manuellement → surveiller la progression → vérifier que le job se termine sans erreur.

### Configurer Hyper Backup → Backblaze B2 (backup hors-site automatique) `NAS + B2`

> **Recommandation audit** : Le boîtier ORICO couvre la panne locale et la suppression accidentelle. Backblaze B2 couvre le sinistre physique (incendie, vol). C'est la pièce hors-site de la règle 3-2-1 — automatique, sans manipulation, ~1€/mois pour 100 Go.

- 1. Créer un compte sur **backblaze.com** → B2 Cloud Storage → Create Bucket → nom : `homelab-backup` → Private → activer **Object Lock** (optionnel, protège contre la suppression accidentelle).
- 2. App Keys → Create Application Key → accès limité au bucket `homelab-backup` → noter le **keyID** et **applicationKey** (affichés une seule fois).
- 3. UGOS Pro → Hyper Backup → Create → **B2 Cloud Storage**.
- 4. Saisir le keyID et applicationKey → sélectionner le bucket `homelab-backup`.
- 5. Mêmes dossiers que le job local : **appdata** · **nextcloud** · **backups**. Exclure **timemachine** (trop volumineux pour B2, déjà couvert localement).
- 6. Activer **Client-side encryption** → utiliser le **même mot de passe** que le job ORICO pour simplifier.
- 7. Planification : tous les jours à **4h00** (après le job ORICO de 3h).
- 8. Premier backup → sera plus long (upload selon ta connexion). Les suivants sont incrémentiels et rapides.

> Règle 3-2-1 complète et 100% automatique · **Copie 1** : RAID 1 NAS (données en temps réel) · **Copie 2** : ORICO RAID 1 via Hyper Backup (versionné, local, nightly) · **Copie 3** : Backblaze B2 (hors-site, chiffré, automatique, ~1€/mois). Zéro manipulation manuelle.

### Tester la restauration des backups (local + B2) `NAS`

> **Recommandation audit** : 🛡 **Recommandation audit — Priorité haute.** Un backup non testé n'est pas un backup. Valider l'intégrité de chaque job en restaurant un fichier test. À refaire mensuellement.

- 1. UGOS Pro → Hyper Backup → sélectionner le **job ORICO** → Restore → choisir un fichier ou dossier test → restaurer vers un emplacement temporaire.
- 2. Vérifier que le fichier restauré est intact et lisible. Comparer avec l'original.
- 3. Faire la même chose pour le **job Backblaze B2** → Restore → fichier test → vérifier l'intégrité.
- 4. Supprimer les fichiers de test restaurés une fois la validation terminée.
- 5. Mettre un **rappel mensuel** (dans Nextcloud Calendar) pour refaire ce test régulièrement.

> Les deux jobs de restauration fonctionnent ✓ — la règle 3-2-1 est validée de bout en bout, pas seulement en écriture.


## 12 - UPS & NUT — arrêt automatique
*Sécurité électrique · Eaton Ellipse PRO 1600 FR*
Câblage · ~110W de charge · NUT 2.8 · driver usbhid-ups · netserver

### Câbler l'Eaton Ellipse PRO 1600 `UPS`

> **Note** : Charge estimée : UM790 ~35W + NAS ~45W + switch ~8W + box ~15W = **~103W** sur 1000W disponibles (~10%). Autonomie estimée : **40 à 55 minutes** à cette charge.

```
Prises "Battery + Surge" (4 prises secourues)
 UM790 Pro ──→ Prise 1 [secouru batterie]
 NAS UGREEN ──→ Prise 2 [secouru batterie]
 Switch TP-Link ──→ Prise 3 [secouru batterie]
 Box internet ──→ Prise 4 [secouru batterie]
 Prises "Surge only" (4 prises protection surtension)
 Mac mini M4 Pro ──→ Prise 5 [surge only — batterie interne Mac]
 Dell U3223QE ──→ Prise 6 [surge only]
 Communication USB
 Port USB Eaton ──→ Port USB-A du UM790 [câble fourni avec l'Eaton · NUT lit l'état batterie]
```

### Installer et configurer NUT `UM790 (root)`

> **Note** : Driver confirmé pour l'Eaton Ellipse PRO 1600 : **usbhid-ups** avec vendorID `0463` productID `ffff` (validé NUT 2.8.0, GitHub #3010).

**SSH — UM790 (root) · Installation NUT**
```bash
apt install -y nut nut-client

# Vérifier que l'UPS est détecté
lsusb | grep -i "0463\|MGE\|Eaton"
# → Bus 001 Device 0XX: ID 0463:ffff MGE UPS Systems UPS

# Scanner pour confirmation
nut-scanner -U
# → driver="usbhid-ups" vendorid="0463" productid="ffff"
```

**/etc/nut/ups.conf**
```ini
[eaton]
 driver = usbhid-ups
 port = auto
 desc = "Eaton Ellipse PRO 1600 FR"
 vendorid = 0463
 productid = ffff
 maxretry = 3
```

**/etc/nut/nut.conf**
```ini
MODE=netserver
```

**/etc/nut/upsd.conf**
```ini
LISTEN 127.0.0.1 3493
LISTEN 192.168.1.10 3493
```

**/etc/nut/upsd.users — utiliser de vrais mots de passe**
```ini
[upsmonitor]
 password = MOT_DE_PASSE_FORT_1
 upsmon primary

[nasmonitor]
 password = MOT_DE_PASSE_FORT_2
 upsmon secondary
```

**/etc/nut/upsmon.conf**
```ini
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

**Démarrer NUT + vérifier**
```bash
systemctl enable --now nut-server nut-monitor nut-driver-enumerator
upsdrvctl start
upsc eaton
# Valeurs attendues :
# ups.status: OL ← On Line = sur secteur
# battery.charge: 100
# ups.load: 10 ← ~10% de charge
# device.model: Ellipse PRO 1600

# Autoriser le NAS à se connecter au serveur NUT
ufw allow from 192.168.1.11 to any port 3493
```

### Configurer le NAS UGREEN comme client NUT `NAS`

> UGOS Pro a un client NUT intégré. Quand l'UPS est sur batterie et que le niveau descend, le NAS s'arrête proprement avant extinction — même sans câble USB entre l'UPS et le NAS.

- 1. UGOS Pro → Control Panel → Hardware → UPS.
- 2. Sélectionner **Network UPS** (pas USB).
- 3. Adresse du serveur NUT : `192.168.1.10`.
- 4. Nom UPS : `eaton` · Utilisateur : `nasmonitor` · Mot de passe : configuré dans upsd.users.
- 5. Délai avant arrêt : 120 secondes · Appliquer.


## 13 - Vérification — tout fonctionne
*Validation complète · Checklist finale*
Homelab production-ready · Stack souveraine · Sécurité électrique

### Checklist de validation complète `Validation`

- ✓ **KVM Dell :** switch Mac ↔ UM790 avec raccourci clavier. Écran bascule en moins de 3 secondes.
- ✓ **SSH :** `ssh homelab` depuis Mac → connexion immédiate sans mot de passe.
- ✓ **Réseau :** `ping 192.168.1.10` (UM790) et `ping 192.168.1.11` (NAS) répondent depuis le Mac.
- ✓ **NFS :** `df -h | grep nas` → les 4 volumes NAS montés sur le UM790.
- ✓ **Coolify :** http://192.168.1.10:8000 accessible · GitHub connecté · premier déploiement réussi.
- ✓ **Tunnel :** `systemctl status cloudflared` → active (running) · Cloudflare Zero Trust → HEALTHY.
- ✓ **Nextcloud :** https://cloud.tondomain.com accessible · calendrier synchro Mac · photos iPhone sauvegardées.
- ✓ **Time Machine :** Réglages système → Time Machine → sauvegarde active · premier backup en cours.
- ✓ **UPS :** `upsc eaton | grep status` → `ups.status: OL` · NAS configuré en client NUT.
- ✓ **Sécurité SSH :** `ssh root@192.168.1.10` → doit être refusé (PermitRootLogin no).
- ✓ **Uptime Kuma :** https://status.tondomain.com → surveille tous les services · alertes configurées.
- ✓ **Hyper Backup local :** job ORICO actif → premier backup terminé sans erreur · chiffrement AES-256 activé · planification 3h00.
- ✓ **Hyper Backup B2 :** job Backblaze B2 actif → premier upload terminé · planification 4h00 · bucket `homelab-backup` visible sur backblaze.com.
- ✓ **Test restauration :** un fichier restauré avec succès depuis le job ORICO ET depuis le job B2.

> **Resultat** : 🏠
 Homelab production-ready et durci. Stack souveraine complète. Sécurité électrique assurée. Hardening validé (Fail2Ban + auto-upgrades + Docker 127.0.0.1). Score audit : A-.

### Commandes de diagnostic quotidiennes `UM790`

**Commandes utiles au quotidien**
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
