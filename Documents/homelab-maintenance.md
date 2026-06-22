---
title: Homelab — Maintenance
date: 2026-04-11
tags: [homelab, maintenance, ops]
---

# Homelab — Maintenance

Procédures récurrentes pour maintenir le homelab en état de production. Organisé en fréquences (quotidien → annuel) puis en procédures ponctuelles (upgrades, restauration, incident).

## 1. Routine quotidienne — automatisée depuis 2026-05-10

La routine est désormais couverte en deux étages, plus besoin d'exécution manuelle :

**Étage continu — Beszel** (hub UI sur `http://192.168.129.10:8090`, LAN-only)
- Surveille en temps réel : CPU, RAM, disque, température, état Docker containers, services systemd
- Alertes Telegram automatiques quand les seuils sont franchis (Status, CPU > 80 % / 5 min, Mem > 90 % / 5 min, Disk > 85 %, Temp > 80 °C)
- Stack docker-compose : `~/apps/beszel/`

**Étage rituel matinal — script bash** (`/usr/local/bin/homelab-morning.sh`)
- Cron `30 7 * * *` — rapport quotidien sur Telegram
- Couvre les indicateurs métier non vus par Beszel : UPS NUT, dernière sauvegarde B2, fail2ban SSH, 3 URLs Cloudflare publiques
- Verdict en première ligne : `OK` ou `DÉGRADÉ`
- Log local : `~/.local/state/homelab-morning.log`

**Pour vérification ponctuelle (ad-hoc)**, utiliser cette commande regroupée :

```bash
ssh homelab '
echo "=== Services ===" && systemctl is-active docker nut-server cloudflared fail2ban ufw
echo "=== Containers unhealthy ===" && docker ps --filter "health=unhealthy" --format "{{.Names}}"
echo "=== Onduleur ===" && upsc eaton@localhost 2>/dev/null | grep -E "ups.status|battery.charge"
echo "=== Températures ===" && for d in /sys/class/hwmon/hwmon*; do
  n=$(cat $d/name 2>/dev/null)
  case "$n" in k10temp|nvme|amdgpu|spd5118) ;; *) continue;; esac
  for t in $d/temp*_input; do
    [ -f "$t" ] || continue
    lbl=$(cat ${t%_input}_label 2>/dev/null || basename ${t%_input} _input)
    printf "  %-10s %-12s %3d°C\n" "$n" "$lbl" "$(($(cat $t)/1000))"
  done
done
echo "=== Backup B2 (dernière ligne) ===" && grep "B2 backup complete" /var/log/rclone-b2-backup.log | tail -1
'
```

Seuils de référence (températures) : k10temp/CPU < 75 °C, NVMe < 70 °C, amdgpu < 75 °C, SPD5118 (DDR5) < 70 °C. Au-delà, vérifier ventilation du caisson et charge en cours.

**Check température NAS Ugreen (.21)** — séparé car SSH différent :

```bash
ssh Steph@192.168.129.21 '
echo "=== SoC ===" && for f in /sys/class/thermal/thermal_zone*/temp; do
  z=$(dirname $f)
  printf "  %-20s %3d°C\n" "$(cat $z/type)" "$(($(cat $f)/1000))"
done
echo "=== Disques RAID + USB ===" && for d in sdb sdc; do
  t=$(sudo -n /usr/sbin/smartctl -A /dev/$d 2>/dev/null | awk "/^194 Temperature_Celsius/ {print \$10; exit}")
  printf "  /dev/%s (HDD)         %3s°C\n" "$d" "${t:-N/A}"
done
t_ssd=$(sudo -n /usr/sbin/smartctl -A /dev/sda 2>/dev/null | awk "/^Temperature:/ {print \$2; exit}")
printf "  /dev/sda (NVMe USB)   %3s°C\n" "${t_ssd:-N/A}"
'
```

Pré-requis : sudoers NOPASSWD pour `smartctl` sur le NAS (`/etc/sudoers.d/smartctl-nopasswd` → `Steph ALL=(root) NOPASSWD: /usr/sbin/smartctl`). Sans cette règle, les lignes disque renvoient `N/A`.

Seuils NAS : SoC RK3588 < 80 °C (throttling vers 95 °C), HDD IronWolf < 55 °C (cible 40-50 °C), NVMe USB < 70 °C.

Vérifier aussi :
- Beszel dashboard : `http://192.168.129.10:8090` (alertes en cours, métriques live)
- Uptime Kuma : `https://uptime.anthemion.dev` (historique uptime, déjà en place)

**Note historique** : ce workflow remplace l'ancien skill OpenClaw `homelab-status` qui tournait via cron LLM à 07:30 (désactivé le 2026-05-10 suite au cap workspace API Anthropic atteint).

## 1bis. Postgres mutualisé (ajouté 2026-04-11)

Un Postgres 16-alpine tourne en container standalone `postgres-shared` sur le réseau Docker `coolify`. Les apps Coolify (ladtc, HillsRun-api, etc.) le joignent en `postgres-shared:5432`.

- **Conteneur** : `postgres-shared` (image `postgres:16-alpine`)
- **Volume** : `postgres-shared-data` (bind par défaut Docker)
- **User admin** : `admin`
- **Mot de passe** : stocké uniquement dans `/home/steph/.secrets/postgres-shared.pass` (mode 600, parent 700), jamais en argv ni dans l'historique shell
- **Création d'un schéma pour une app** :
  ```bash
  ssh homelab 'docker exec -e PGPASSWORD="$(cat ~/.secrets/postgres-shared.pass)" postgres-shared \
    psql -U admin -d postgres -c "CREATE DATABASE ladtc; CREATE USER ladtc WITH PASSWORD '\''...'\''; GRANT ALL ON DATABASE ladtc TO ladtc;"'
  ```
- **Sauvegarde** : `pg_dumpall` quotidien via `/usr/local/bin/b2-backup.sh`, envoyé dans `/mnt/nas/backups/pg/` puis synchronisé B2. Rotation : 7 dumps locaux conservés.
- **Restauration** : `gunzip -c /mnt/nas/backups/pg/pgdumpall-YYYYMMDD-HHMMSS.sql.gz | docker exec -i postgres-shared psql -U admin`

## 2. Routine hebdomadaire — 10 minutes

### 2.1 Espace disque

```bash
ssh homelab 'df -h / /mnt/nas/*'
```

Seuils d'alerte :
- `/` > 80 % → investiguer (logs, images Docker orphelines)
- `/mnt/nas/*` > 80 % → planifier extension NAS ou purge

### 2.2 Mises à jour système (automatiques mais vérifier)

```bash
ssh homelab 'cat /var/log/unattended-upgrades/unattended-upgrades.log | tail -30'
```

S'assurer qu'`unattended-upgrades` tourne sans erreur. Un reboot est nécessaire si `/var/run/reboot-required` existe :

```bash
ssh homelab 'test -f /var/run/reboot-required && echo "REBOOT REQUIRED" || echo "OK"'
```

Planifier un reboot manuel dans une fenêtre calme (voir procédure 6.1).

### 2.3 Intégrité `daemon.json` Docker

Coolify peut réécrire ce fichier. Vérifier :

```bash
ssh homelab 'grep -q "\"ip\": \"127.0.0.1\"" /etc/docker/daemon.json && echo OK || echo "MISSING"'
```

Si `MISSING` → restaurer (voir `homelab-troubleshooting.md` 2.1).

### 2.4 Fail2Ban — bans actifs

```bash
ssh homelab 'sudo fail2ban-client status sshd'
```

Nombre anormalement élevé d'IP bannies → signal d'attaque brute-force ciblée.

### 2.5 Logs erreurs containers

```bash
ssh homelab 'for c in $(docker ps -q); do
  n=$(docker inspect --format "{{.Name}}" $c);
  err=$(docker logs --since 7d $c 2>&1 | grep -ciE "error|fatal|panic");
  [ "$err" -gt 10 ] && echo "$n : $err erreurs";
done'
```

## 3. Routine mensuelle — 30 minutes

### 3.1 Mise à jour Coolify

Via l'UI : Settings → Update. Vérifier ensuite :
- Tous les containers Coolify redémarrent sainement
- `daemon.json` toujours conforme (voir 2.3)
- Les services déployés restent accessibles (`curl` via tunnel)

### 3.2 Mise à jour Nextcloud AIO

Via l'interface admin (`https://127.0.0.1:8181` en tunnel SSH) : bouton "Check for updates". AIO gère lui-même la stack (pull, restart en ordre).

Après upgrade :
- Vérifier `cloud.anthemion.dev` (login)
- Contrôler les apps installées dans Nextcloud (Settings → Apps)
- Vérifier les occ warnings : `docker exec --user www-data nextcloud-aio-nextcloud php occ status`

### 3.3 Test de restauration backup B2

Un backup jamais testé n'existe pas. Une fois par mois, restaurer un fichier témoin :

```bash
ssh homelab '
mkdir -p /tmp/restore-test
rclone copy b2:homelab-backup-anthemion/nextcloud/data/README.md /tmp/restore-test/
ls -la /tmp/restore-test/
'
```

Remplacer `README.md` par un fichier réellement présent. Comparer avec la source. Nettoyer ensuite.

### 3.4 Vérification snapshots NAS

Se connecter à l'interface UGOS → Storage → Snapshots. Confirmer qu'une série de snapshots récents existe (rétention 30 jours attendue).

### 3.5 Purge images Docker orphelines

```bash
ssh homelab 'docker image prune -af --filter "until=720h"'
```

(images non utilisées depuis 30 jours)

### 3.6 Logs NUT

```bash
ssh homelab 'journalctl -u nut-server -u nut-monitor --since "30 days ago" --no-pager | grep -iE "error|comm lost|low battery"'
```

Aucune `comm lost` persistante ne doit apparaître. Si oui → câble USB onduleur suspect.

## 4. Routine trimestrielle — 1 heure

### 4.1 Test d'autotest onduleur

```bash
ssh homelab 'sudo upscmd eaton test.battery.start.quick'
```

Attendre ~30 s puis :

```bash
ssh homelab 'upsc eaton@localhost ups.test.result'
```

Résultat attendu : `Done and passed`. Un résultat différent → prévoir remplacement batterie (cycle typique 3-5 ans).

### 4.2 Rotation des logs applicatifs

Vérifier tailles :

```bash
ssh homelab 'sudo du -sh /var/log/* | sort -h | tail -10'
```

Si un log dépasse 500 Mo, `logrotate` mal configuré — investiguer.

### 4.3 Audit UFW / Fail2Ban

Revérifier que la liste des règles UFW correspond au manuel section 3. Tout port ouvert non listé = anomalie à comprendre.

```bash
ssh homelab 'sudo ufw status numbered'
```

### 4.4 Rotation des secrets sensibles

- Token Cloudflare Tunnel si compromission suspectée
- Mots de passe NUT (optionnel, faible exposition)
- Application Key Backblaze B2 → générer une nouvelle clé, mettre à jour `rclone.conf`, révoquer l'ancienne

## 5. Routine annuelle

### 5.1 Upgrade Ubuntu LTS point release

Ubuntu 24.04 → 24.04.N via `apt upgrade`. Les majeures LTS → LTS (24.04 → 26.04) ne se feront qu'en 2026/2027 avec un plan dédié.

Procédure :

```bash
ssh homelab 'sudo apt update && sudo apt full-upgrade -y && sudo apt autoremove -y'
# Puis, si reboot-required :
ssh homelab 'sudo reboot'
```

### 5.2 Vérification complète 3-2-1

- Copie 1 (NAS snapshot) : existe, <24 h
- Copie 2 (disque externe ORICO) : rotation quotidienne OK, disque en bonne santé (SMART via UGOS)
- Copie 3 (B2) : test restauration d'un dossier réel (pas juste un fichier)

### 5.3 Inventaire matériel

Consigner : heures d'utilisation, état disque NVMe UM880 (`smartctl`), état batterie onduleur, état ventilation UM880 (bruit anormal, température).

```bash
ssh homelab 'sudo smartctl -a /dev/nvme0n1 | grep -E "Available Spare|Percentage Used|Media and Data"'
```

## 6. Procédures ponctuelles

### 6.1 Reboot propre de l'UM880

Ordre strict :

```bash
ssh homelab '
sudo systemctl stop cloudflared &&
docker stop $(docker ps -q) &&
sudo reboot
'
```

Docker et les services redémarrent au boot grâce à `restart: unless-stopped`. Prévoir 2-3 minutes avant que tous les containers soient healthy.

### 6.2 Reboot du NAS

À déclencher depuis l'UI UGOS pour laisser Samba/NFS se fermer proprement. Prévenir que les montages NFS UM880 vont temporairement faillir (`df -h` se bloquera). Les containers qui écrivent sur NFS (Nextcloud AIO) entreront en erreur et se relèveront après remount.

Après reboot NAS :

```bash
ssh homelab 'sudo mount -a && df -h /mnt/nas/*'
```

Si un montage refuse, `sudo umount -f /mnt/nas/<share>` puis `sudo mount -a`.

### 6.3 Coupure électrique prolongée

L'onduleur Ellipse PRO 1600 fournit ~1 h à 0 % de charge mesurée. NUT déclenche le shutdown quand la batterie tombe sous le seuil. Actions après restauration courant :

1. Le UM880 reboote automatiquement
2. Vérifier `systemctl is-active ...` et `docker ps`
3. Contrôler les 3 URL publiques (coolify, uptime, cloud)
4. Vérifier le log NUT : `journalctl -u nut-monitor --since "1h ago"`

### 6.4 Restauration Nextcloud depuis backup

1. Arrêter Nextcloud AIO : via interface admin, bouton Stop
2. Restaurer les données depuis B2 :

```bash
rclone sync b2:homelab-backup-anthemion/nextcloud/data /mnt/nas/nextcloud/data --dry-run
```

   Contrôler le dry-run avant de retirer `--dry-run`.
3. Restaurer la base postgres depuis le dump AIO (Nextcloud AIO gère ses propres dumps dans `nextcloud_aio_nextcloud_data_dump`)
4. Redémarrer AIO

Procédure complète documentée dans l'admin AIO → "Backup and restore".

### 6.5 Ajouter un nouveau service derrière Cloudflare Tunnel

1. Déployer le service dans Coolify avec le FQDN voulu (ex. `mon-service.anthemion.dev`)
2. Dans Cloudflare Zero Trust → Access → Tunnels → tunnel existant → Public Hostname → Add
3. Renseigner : Hostname `mon-service.anthemion.dev`, Service `http://localhost:80`
4. Valider. Tester `curl -I https://mon-service.anthemion.dev` dans la minute qui suit

### 6.6 Changement d'IP LAN (ex. nouvelle box)

Ordre pour éviter de se verrouiller dehors :

1. Écran + clavier sur UM880 (pas SSH)
2. Modifier `/etc/netplan/00-installer-config.yaml` → nouvelle adresse et gateway
3. `sudo netplan try` → valider à la main pendant les 120 s
4. Mettre à jour l'alias `homelab` dans `~/.ssh/config` côté Mac
5. Sur le NAS : ajuster les autorisations NFS si l'IP UM880 change
6. Sur NUT : `upsd.conf` et `upsmon.conf` (LISTEN et MONITOR)
7. Sur fstab : les chemins NFS ne changent que si c'est l'IP NAS qui bouge

## 7. Indicateurs de santé à suivre

| Indicateur | Seuil vert | Seuil orange | Où ? |
|---|---|---|---|
| Uptime UM880 | reboot mensuel | >90 j sans reboot | `uptime` |
| Charge NVMe | < 10 % used | > 50 % used | `smartctl` |
| Batterie onduleur | > 95 % | < 80 % | `upsc` |
| NFS latence | < 30 ms | > 100 ms | `time ls /mnt/nas/appdata` |
| Containers unhealthy | 0 | ≥ 1 | `docker ps --filter health=unhealthy` |
| Fail2Ban bans actifs | < 20 | > 100 | `fail2ban-client status sshd` |
| Succès backup B2 | quotidien | > 48 h sans succès | `/var/log/rclone-b2-backup.log` |
| Certificat Cloudflare | auto-renouvelé | erreur cert | test `curl -v` |

## 8. Checklist mensuelle — format imprimable

- [ ] UFW status conforme
- [ ] daemon.json contient `"ip": "127.0.0.1"`
- [ ] 3 URL publiques répondent en < 1 s
- [ ] `df -h` < 80 % sur tous les volumes
- [ ] Backup B2 quotidien OK (log < 36 h)
- [ ] Snapshots NAS récents
- [ ] Coolify à jour
- [ ] Nextcloud AIO à jour
- [ ] Aucune container unhealthy
- [ ] `upsc` : OL, batterie > 95 %
- [ ] Test restauration d'un fichier depuis B2
- [ ] `unattended-upgrades` log sans erreur
- [ ] Pas de `/var/run/reboot-required` ou reboot planifié

Cocher dans la daily note Obsidian du jour de maintenance.
