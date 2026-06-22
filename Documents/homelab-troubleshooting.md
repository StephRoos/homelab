---
title: Homelab — Troubleshooting
date: 2026-04-11
tags: [homelab, troubleshooting]
---

# Homelab — Troubleshooting

Catalogue des incidents rencontrés pendant l'installation et des correctifs appliqués. Chaque entrée décrit le symptôme, la cause racine et la résolution vérifiée. À compléter au fil des incidents futurs.

## 1. Réseau & système

### 1.1 Docker casse le réseau après reboot (Debian 13)

**Symptôme** : après installation de Docker sur Debian 13, plus aucune connexion réseau au reboot. Aucun accès SSH.

**Cause** : conflit entre Docker (iptables-legacy) et Debian 13 (nftables par défaut). Les règles Docker corrompent la table nftables.

**Correctif** : réinstallation complète en **Ubuntu Server 24.04 LTS** qui gère nativement la compatibilité iptables-nft. Ne plus tenter Docker sur Debian 13.

### 1.2 IP attribuée dans un sous-réseau inattendu

**Symptôme** : `ip a` affiche une adresse en `192.168.129.x` alors que la gateway est `192.168.128.1`. Confusion sur le sous-réseau réel.

**Cause** : configuration atypique de la b-box Proximus qui assigne le DHCP dans `192.168.129.0/24` mais garde la gateway en `192.168.128.1`.

**Correctif** : utiliser `192.168.129.x/24` avec route par défaut explicite vers `192.168.128.1` dans netplan. Voir `homelab-manuel.md` section 2.

### 1.3 Netplan YAML indentation incohérente

**Symptôme** : `sudo netplan apply` échoue avec "inconsistent indentation: addresses:".

**Cause** : mélange tabulations/espaces introduit en collant du texte par SSH.

**Correctif** : éditer avec `nano` ou écrire via `python3 -c` (jamais de heredoc indenté via SSH). Toujours utiliser 2 espaces, jamais de tab.

### 1.4 WiFi UM880 absent

**Symptôme** : aucune interface `wl*` visible, aucun SSID détecté. `linux-firmware` installé sans effet.

**Cause** : carte MediaTek MT7902 sans driver Linux stable (driver communautaire `hmtheboy154/mt7902` non maintenu).

**Correctif** : ethernet uniquement. Pour un besoin d'installation temporaire sans câble, utiliser le tethering USB Android (Pixel 8 → UM880 via câble USB-C, mode "Partage de connexion USB").

### 1.5 sudo demande un mot de passe en SSH non-interactif

**Symptôme** : commandes `ssh homelab 'sudo ...'` échouent silencieusement.

**Correctif** : `/etc/sudoers.d/steph` avec `steph ALL=(ALL) NOPASSWD:ALL`. Vérifier les permissions `chmod 440`.

## 2. Docker

### 2.1 Coolify réécrit `/etc/docker/daemon.json`

**Symptôme** : après mise à jour Coolify, le champ `"ip": "127.0.0.1"` disparaît. Les containers ré-exposent des ports sur toutes les interfaces.

**Correctif** :

```bash
sudo python3 -c '
import json
p = "/etc/docker/daemon.json"
d = json.load(open(p))
d["ip"] = "127.0.0.1"
json.dump(d, open(p, "w"), indent=2)
'
sudo systemctl restart docker
```

Vérifier dans la maintenance hebdomadaire.

### 2.2 502 Bad Gateway sur Nextcloud après restart Docker

**Symptôme** : juste après un `systemctl restart docker`, `cloud.anthemion.dev` renvoie 502 pendant ~1 min.

**Cause** : la stack Nextcloud AIO (database → nextcloud → apache) démarre en cascade avec healthchecks.

**Correctif** : attendre 60-90 s. Si le 502 persiste au-delà, voir `docker ps` et vérifier que `nextcloud-aio-apache` est `healthy`.

## 3. Coolify / Traefik

### 3.1 Traefik 404 sur un nouveau domaine

**Symptôme** : après ajout d'un domaine dans Coolify, Traefik renvoie 404.

**Cause** : les labels Traefik ne sont recalculés qu'au redeploy, pas au save.

**Correctif** : bouton "Redeploy" sur le service dans Coolify.

### 3.2 Uptime Kuma 502 derrière Cloudflare Tunnel

**Symptôme** : `uptime.anthemion.dev` renvoie 502 en sortie de tunnel.

**Cause** : le tunnel pointe sur `http://uptime.homelab` (nom non résolu par cloudflared) au lieu du vhost Traefik.

**Correctif** : dans Coolify, utiliser directement le domaine public (`https://uptime.anthemion.dev`) comme FQDN du service, et faire pointer cloudflared sur `http://localhost:80`. Traefik fera le routing via `Host:` header.

### 3.3 nip.io ne résout pas

**Symptôme** : `*.nip.io` ne répond pas depuis le LAN Proximus.

**Cause** : résolveur DNS de la box ou filtrage.

**Correctif** : utiliser une entrée `/etc/hosts` en local Mac plutôt que nip.io pour tout test LAN.

## 4. Nextcloud AIO

### 4.1 "Domaincheck container is not running"

**Symptôme** : impossible de valider le domaine `cloud.anthemion.dev` dans l'interface AIO. Message répété "Domaincheck container is not running".

**Cause** : port `11000` déjà publié par le mastercontainer, empêchant le container enfant `nextcloud-aio-domaincheck` de le binder.

**Correctif** : retirer `-p 11000:11000` de la commande `docker run` du mastercontainer. Seule `APACHE_PORT=11000` + `APACHE_IP_BINDING=0.0.0.0` en variables d'environnement suffit — AIO publie lui-même le port via son container apache enfant.

### 4.2 Conflit port 8080 entre AIO admin et Traefik

**Symptôme** : AIO ne démarre pas, port 8080 déjà occupé par `coolify-proxy`.

**Correctif** : binder l'admin AIO sur `127.0.0.1:8181` → `8080` interne. Accès via tunnel SSH `ssh -L 8181:127.0.0.1:8181 homelab`.

### 4.3 Coolify ne comprend pas le Compose AIO

**Symptôme** : erreurs de parse "Unable to parse at line X" en essayant d'importer Nextcloud AIO dans Coolify.

**Cause** : Coolify n'est pas fait pour piloter un mastercontainer qui spawn ses propres enfants.

**Correctif** : déployer Nextcloud AIO **en dehors** de Coolify via un `docker run` natif. Coolify reste utile pour les autres services applicatifs.

## 5. NAS & Time Machine

### 5.1 Le NAS n'apparaît pas dans Time Machine

**Symptôme** : le partage SMB `timemachine` est accessible mais ne figure pas dans les destinations Time Machine de macOS.

**Cause** : publication mDNS Avahi manquante. Time Machine scanne `_adisk._tcp` en Bonjour.

**Correctif** : créer `/etc/avahi/services/timemachine.service` sur le NAS (voir manuel section 9) puis `sudo systemctl restart avahi-daemon`.

### 5.2 Option Time Machine absente dans l'UI UGOS

**Symptôme** : aucune case "Time Machine" dans File Station / Samba UGOS.

**Correctif** : éditer directement `/etc/samba/smbshare.conf` sur le NAS en SSH et ajouter les directives `fruit:time machine`. Mot de passe sudo du NAS conservé dans le gestionnaire.

### 5.3 UGOS n'a ni Hyper Backup ni sortie B2 native

**Symptôme** : impossible de sauvegarder vers Backblaze B2 depuis l'UI UGOS.

**Correctif** : utiliser `rclone` installé sur le UM880 avec cron quotidien (voir manuel section 10). L'UM880 lit les partages NFS et pousse vers B2.

### 5.4 Bucket B2 "already in use"

**Symptôme** : création bucket échoue — nom réservé globalement.

**Cause** : les noms de bucket Backblaze sont globaux. Un nom non unique est rejeté.

**Correctif** : préfixer par un suffixe lisible (`homelab-backup-anthemion`). Bien activer Object Lock **à la création** — impossible de l'ajouter ensuite sans recréer.

## 6. NUT / Onduleur

### 6.1 Driver `usbhid-ups` refuse `maxretry`

**Symptôme** : `upsdrvctl start eaton` échoue avec "maxretry not a valid parameter".

**Correctif** : retirer la ligne `maxretry = 3` de `/etc/nut/ups.conf`. Ce paramètre n'existe pas pour `usbhid-ups`.

### 6.2 Permission denied sur le device USB onduleur

**Symptôme** : `Can't claim USB device` dans les logs `upsdrvctl`.

**Cause** : l'utilisateur `nut` n'a pas accès à `/dev/bus/usb/...`.

**Correctif** : créer `/etc/udev/rules.d/90-nut-ups.rules` avec `GROUP="nut"` (voir manuel), puis :

```bash
sudo udevadm control --reload-rules
sudo udevadm trigger
sudo usermod -aG plugdev nut
sudo systemctl restart nut-driver nut-server
```

### 6.3 Client NUT sur le NAS ne se connecte pas

**Symptôme** : `upsc eaton@192.168.129.10` échoue depuis le NAS.

**Causes possibles** :
- `MODE=netclient` manquant dans `/etc/nut/nut.conf` sur le NAS
- Ligne `MONITOR` absente dans `/etc/nut/upsmon.conf`
- UFW UM880 bloque le port 3493 depuis le NAS

**Correctif** : vérifier les trois points. UFW doit contenir `ALLOW IN 3493 from 192.168.129.21`.

## 7. Cloudflare Tunnel

### 7.1 Le service tunnel ne démarre pas au boot

**Symptôme** : `systemctl status cloudflared` inactif.

**Correctif** : `sudo cloudflared service install <TOKEN>` doit être lancé une seule fois — il crée le service systemd. Vérifier avec `systemctl is-enabled cloudflared`.

### 7.2 Un nouveau hostname ne prend pas effet

**Symptôme** : après ajout d'un public hostname dans le dashboard Cloudflare Zero Trust, 502.

**Correctif** : le tunnel pull la config en pushmode — la propagation est rapide (quelques secondes). Si 502 persiste, vérifier que le service interne pointé répond bien sur `localhost` avec le bon port. `curl -v http://localhost:PORT` depuis l'UM880.

## 8. Récupération après coupure brutale (caisson antibruit)

Voir aussi la procédure dédiée : [[homelab-restart-after-outage]].

### 8.1 Conteneurs Docker `unless-stopped` qui ne remontent pas au boot

**Symptôme** : après une coupure brutale (alim coupée alors que le système tourne), plusieurs conteneurs restent `Exited` avec code 143 (SIGTERM) ou 137 (SIGKILL) malgré une `RestartPolicy=unless-stopped`. Docker considère qu'un conteneur stoppé "explicitement" avant l'extinction (par signal) ne doit pas être relancé au boot.

**Cause** : la coupure d'alim envoie SIGTERM/SIGKILL aux processes. Docker enregistre ces arrêts comme "explicites" du point de vue de `unless-stopped`. Les conteneurs sont marqués stoppés intentionnellement.

**Correctif** : démarrer manuellement les conteneurs concernés, dans l'ordre de leurs dépendances (DBs d'abord) :
```bash
docker start postgres-shared
docker start beszel beszel-agent portfolio-staging
```

### 8.2 Réseau Docker Coolify perdu au reboot — conteneurs orphelins

**Symptôme** : `docker start app-<projectUUID>-...` échoue avec `failed to set up container networking: network <hash> not found`. Le hash correspond à un network Docker créé par Coolify lors d'un précédent deploy mais disparu après reboot.

**Cause** : l'ID du réseau Docker (et non son nom) est gravé dans la config du conteneur au moment du `docker create`. Si le réseau est supprimé (ou jamais recréé après reboot), recréer un réseau du même nom ne donne pas le même ID, donc le conteneur reste orphelin.

**Correctif** : recréer les conteneurs via un redeploy Coolify. Coolify n'expose pas d'artisan command direct ; passer par le helper PHP `queue_application_deployment()` :
```bash
# 1. Remove dead containers (les volumes data sont préservés)
docker rm app-<projectUUID>-<oldId> db-<projectUUID>-<oldId>

# 2. Trigger Coolify redeploy via tinker
docker exec coolify php artisan tinker --execute='
$app = \App\Models\Application::where("uuid", "<projectUUID>")->first();
$uuid = (string) new \Visus\Cuid2\Cuid2(7);
queue_application_deployment(application: $app, deployment_uuid: $uuid, no_questions_asked: true);
'

# 3. Suivre l'état
docker exec coolify-db psql -U coolify -d coolify -tAc \
  "SELECT status FROM application_deployment_queues ORDER BY id DESC LIMIT 1;"
```

### 8.3 Stack Nextcloud AIO qui ne redémarre pas seule + configs templated corrompues

**Symptôme** : après reboot, les conteneurs `nextcloud-aio-*` restent `Exited`. Le `nextcloud-aio-mastercontainer` est up et healthy mais ne relance pas sa stack au boot (par design — c'est à l'utilisateur de cliquer "Start" dans l'UI). Au démarrage forcé, `nextcloud-aio-database` et `nextcloud-aio-redis` partent en restart loop avec :
- Postgres : `syntax error in postgresql.conf line 533, near end of line` (ligne `log_min_messages = ` vide).
- Redis : `FATAL CONFIG FILE ERROR: 'loglevel ""' argument(s) must be one of: debug, verbose, notice, warning, nothing`.

**Cause** : le mastercontainer AIO régénère ces fichiers de configuration à chaque démarrage de la stack à partir de templates qui interpolent des variables d'environnement. Une régression upstream (build du 8 mai 2026) laisse certaines variables vides → templates buggés. Éditer les fichiers manuellement ne tient pas — AIO les écrase au boot suivant.

**Correctif** : déclencher l'update du mastercontainer (qui régénère aussi les templates) via l'API. Le password admin est dans `/var/lib/docker/volumes/nextcloud_aio_mastercontainer/_data/data/configuration.json` (clé `password`). L'UI écoute sur `127.0.0.1:8181` (port interne 8080). Voir le détail dans [[homelab-restart-after-outage]] section 4.

### 8.4 Bug `NEXTCLOUD_LOG_LEVEL` non substitué dans `aio-nextcloud:latest`

**Symptôme** : après update via watchtower, `nextcloud-aio-nextcloud` part en restart loop infini. Log :
```
In CastHelper.php line 20: Non-numeric value specified
config:system:set [--type TYPE] [--value VALUE] ...
```
Le conteneur passe `--value="" --type=integer` à `occ config:system:set loglevel`.

**Cause apparente** : l'entrypoint.sh ligne 674 contient `--value="$NEXTCLOUD_LOG_LEVEL" --type=integer`. Le conteneur en boucle a `NEXTCLOUD_LOG_LEVEL` vide → exit error → restart loop. Mais la **vraie cause** est plus subtile : le master AIO **ne pousse pas** `AIO_LOG_LEVEL` dans l'env du conteneur après certains scénarios (start sur un conteneur préexistant via `docker start`, vs `docker create` sur un nouveau). L'entrypoint.sh dérive `NEXTCLOUD_LOG_LEVEL` de `AIO_LOG_LEVEL` quand cette dernière est présente.

**Symptômes voisins liés au même bug** :
- `nextcloud-aio-apache` peut tomber en restart loop avec `Format string '%(ENV_AIO_LOG_LEVEL)s' for 'supervisord.loglevel' contains names which cannot be expanded` — son supervisord.conf référence `%(ENV_AIO_LOG_LEVEL)s` non substitué.

**Correctif (la solution simple)** : forcer le master à recréer le conteneur, ce qui réinjecte `AIO_LOG_LEVEL=warn` dans l'env :
```bash
# 1. Stop + remove (les volumes data sont préservés)
docker stop nextcloud-aio-nextcloud nextcloud-aio-apache 2>/dev/null
docker rm nextcloud-aio-nextcloud nextcloud-aio-apache

# 2. Re-login API AIO + POST /api/docker/start (cf 8.3 pour la commande complète)
```

Le master AIO recrée alors les conteneurs avec `docker create` (pas `docker start`) et leur passe correctement les variables d'environnement. Vérifier ensuite :
```bash
docker inspect nextcloud-aio-apache --format '{{range .Config.Env}}{{println .}}{{end}}' | grep AIO_LOG_LEVEL
# attendu : AIO_LOG_LEVEL=warn
```

**Note** : le simple `docker start` (sans `rm` préalable) ne fixe pas le bug car le conteneur conserve sa config Env d'origine, qui n'avait pas la variable. C'est uniquement le `docker create` qui regenère depuis le template du master.

**Si la solution simple échoue** (master toujours buggué), fallback en patchant les images localement :
1. Extraire `/entrypoint.sh` et `/supervisord.conf` des images concernées.
2. Remplacer `--value="$NEXTCLOUD_LOG_LEVEL"` par `--value="2"` et `loglevel=%(ENV_AIO_LOG_LEVEL)s` par `loglevel=warn`.
3. Build local avec `FROM ghcr.io/nextcloud-releases/aio-nextcloud:latest`, taggé sur le même nom pour shadow l'image officielle.
4. Stop + remove + redémarrer via l'API AIO.

Le patch image est écrasé au prochain `watchtower` update — utile seulement comme dépannage immédiat.

**Correctif permanent** : attendre que l'image upstream soit rebuild avec le fix `main` (`--value="2"` en dur), puis laisser watchtower repull.

### 8.5 Recommandation Redis : `vm.overcommit_memory = 1`

**Symptôme** : Redis (AIO ou autre) émet `WARNING Memory overcommit must be enabled!` au démarrage.

**Correctif** : appliquer le sysctl et persister :
```bash
sudo sysctl vm.overcommit_memory=1
echo 'vm.overcommit_memory = 1' | sudo tee /etc/sysctl.d/99-nextcloud-redis.conf
```
Référence : [discussion AIO #1731](https://github.com/nextcloud/all-in-one/discussions/1731).

## 9. Commandes de diagnostic rapide

```bash
# État global
ssh homelab 'systemctl is-active docker nut-server nut-monitor cloudflared fail2ban ufw unattended-upgrades'

# Containers
ssh homelab 'docker ps --format "{{.Names}}\t{{.Status}}"'

# Montages NAS
ssh homelab 'df -h /mnt/nas/*'

# Onduleur
ssh homelab 'upsc eaton@localhost | grep -E "battery|ups.status|input.voltage"'

# Sauvegarde B2
ssh homelab 'tail -30 /var/log/rclone-b2-backup.log'

# Tunnel Cloudflare
ssh homelab 'journalctl -u cloudflared --since "1h ago" --no-pager | tail -30'

# Pare-feu
ssh homelab 'sudo ufw status numbered'
```
