---
title: Homelab — Procédure de redémarrage après coupure
date: 2026-05-14
tags: [homelab, procedure, recovery, runbook]
---

# Homelab — Procédure de redémarrage après coupure

Runbook complet à exécuter après une coupure brutale du homelab (alim coupée, kernel panic, reboot non propre). Établi à partir de l'incident du 14 mai 2026 suite à l'installation dans le caisson antibruit.

Voir aussi : [[homelab-troubleshooting]] section 8, [[caisson-anti-bruit-homelab]], [[homelab-maintenance]].

## Contexte et objectif

Une coupure non propre entraîne deux problèmes prévisibles qui ne se résolvent pas automatiquement au boot :
1. Plusieurs conteneurs Docker `unless-stopped` restent `Exited` (codes 143/137) — Docker les considère stoppés explicitement par signal et ne les relance pas.
2. Les **réseaux Docker créés par Coolify** peuvent disparaître. Les conteneurs orphelins refusent de démarrer (network ID gravé dans leur config introuvable).
3. La **stack Nextcloud AIO** ne se redémarre jamais seule (par design AIO) et peut souffrir de templates de config régénérés buggés selon la version courante.

L'objectif de la procédure : remettre tous les services up en moins de 15 minutes, sans perdre de données.

## Étape 0 — Constat initial

```bash
ssh homelab '
echo "=== Système ==="
uptime
echo "=== Conteneurs ==="
docker ps -a --format "table {{.Names}}\t{{.Status}}" | head -25
echo "=== UPS Eaton ==="
upsc eaton@localhost | grep -E "ups.status|battery.charge|input.voltage"
'
```

Repérer :
- Conteneurs `Exited (143)` ou `Exited (137)` → à redémarrer manuellement (étape 1).
- Erreurs `network ... not found` lors d'un `docker start` → besoin d'un redeploy Coolify (étape 2).
- Stack `nextcloud-aio-*` toute en `Exited` malgré un mastercontainer healthy → étape 3.

## Étape 1 — Conteneurs standards (non-AIO, non-Coolify-managed)

Démarrer dans l'ordre des dépendances (bases de données d'abord). Adapter à la liste réelle :

```bash
ssh homelab '
docker start postgres-shared
sleep 3
docker start beszel beszel-agent portfolio-staging
'
```

Vérifier :
```bash
ssh homelab 'docker ps --format "{{.Names}}: {{.Status}}" | grep -vE "Exited|Restarting"'
```

## Étape 2 — Apps Coolify dont le réseau a été perdu

### 2.1 Diagnostic

Tenter `docker start app-<projectUUID>-<id>`. Si l'erreur est `failed to set up container networking: network <hash> not found`, le réseau Coolify a disparu.

### 2.2 Redeploy via tinker

Coolify n'expose pas de commande artisan `deploy`. Le passage par le helper PHP `queue_application_deployment()` reproduit exactement ce qu'un clic "Deploy" dans l'UI déclenche.

```bash
ssh homelab '
APP_UUID="<projectUUID>"   # ex: kmpuu3pdcjlbrlpwauy0entm pour ladtc-prod

# Identifier les conteneurs morts
OLD_APP=$(docker ps -a --format "{{.Names}}" | grep "^app-$APP_UUID-")
OLD_DB=$(docker ps -a --format "{{.Names}}" | grep "^db-$APP_UUID-")
echo "Removing: $OLD_APP $OLD_DB"

# Supprimer (volumes data préservés — ils sont dans des volumes nommés indépendants)
[ -n "$OLD_APP" ] && docker rm "$OLD_APP"
[ -n "$OLD_DB" ] && docker rm "$OLD_DB"

# Trigger deploy
docker exec coolify php artisan tinker --execute="
\$app = \App\Models\Application::where(\"uuid\", \"$APP_UUID\")->first();
\$uuid = (string) new \Visus\Cuid2\Cuid2(7);
\$res = queue_application_deployment(application: \$app, deployment_uuid: \$uuid, no_questions_asked: true);
echo \"deploy_uuid=\$uuid status=\" . (\$res[\"status\"] ?? \"?\") . PHP_EOL;
"
'
```

### 2.3 Suivi du déploiement

```bash
ssh homelab 'docker exec coolify-db psql -U coolify -d coolify -tAc \
  "SELECT deployment_uuid, status, created_at FROM application_deployment_queues ORDER BY id DESC LIMIT 3;"'
```

Le statut passe `queued → in_progress → finished` en ~60 secondes pour une app simple.

### 2.4 Liste des apps Coolify (référence)

Pour retrouver les UUID au moment de la récupération :
```bash
ssh homelab 'docker exec coolify-db psql -U coolify -d coolify -c \
  "SELECT id, name, uuid, fqdn, status FROM applications;"'
```

## Étape 3 — Stack Nextcloud AIO

Le `nextcloud-aio-mastercontainer` est lui-même `unless-stopped` et redémarre seul, mais sa stack interne ne redémarre **jamais** sans intervention humaine — c'est un choix de design AIO pour éviter de masquer des erreurs d'initialisation.

### 3.1 Récupérer le mot de passe admin AIO

```bash
ssh homelab "sudo jq -r .password \
  /var/lib/docker/volumes/nextcloud_aio_mastercontainer/_data/data/configuration.json"
```

### 3.2 Login + démarrage via API

L'UI AIO écoute sur `127.0.0.1:8181` (port 8080 interne du conteneur, mappé sur 8181 hôte) en HTTPS avec cert auto-signé.

```bash
ssh homelab '
PASS="<password-aio>"
COOKIE=/tmp/aio_cookies.txt

# GET login page pour récup CSRF + session cookie
curl -ksL -c $COOKIE -o /tmp/aio.html https://localhost:8181/
CN=$(grep -oE "name=\"csrf_name\" value=\"[^\"]+\"" /tmp/aio.html | head -1 | sed "s/.*value=\"//;s/\".*//")
CV=$(grep -oE "name=\"csrf_value\" value=\"[^\"]+\"" /tmp/aio.html | head -1 | sed "s/.*value=\"//;s/\".*//")

# POST login
curl -ks -b $COOKIE -c $COOKIE -w "login=%{http_code}\n" \
  -X POST https://localhost:8181/api/auth/login \
  --data-urlencode "password=$PASS" \
  --data-urlencode "csrf_name=$CN" \
  --data-urlencode "csrf_value=$CV" -o /dev/null

# Refresh CSRF pour la home post-login
curl -ksL -b $COOKIE -c $COOKIE -o /tmp/aio.html https://localhost:8181/
CN=$(grep -oE "name=\"csrf_name\" value=\"[^\"]+\"" /tmp/aio.html | head -1 | sed "s/.*value=\"//;s/\".*//")
CV=$(grep -oE "name=\"csrf_value\" value=\"[^\"]+\"" /tmp/aio.html | head -1 | sed "s/.*value=\"//;s/\".*//")

# POST start (stream — peut prendre 30-90s)
curl -ks -b $COOKIE --max-time 600 -w "\nstart=%{http_code}\n" \
  -X POST https://localhost:8181/api/docker/start \
  --data-urlencode "csrf_name=$CN" \
  --data-urlencode "csrf_value=$CV" -o /tmp/aio_start.html

# Voir les étapes
grep -oE "<div>[^<]+</div>" /tmp/aio_start.html | sed "s/<[^>]*>//g"
'
```

### 3.3 Si database / redis partent en restart loop

C'est l'incident 8.3 du troubleshooting (templates corrompus). Lancer un update du master qui régénère les templates :

```bash
ssh homelab '
# Suppose cookies encore valides ; sinon refaire login étape 3.2
COOKIE=/tmp/aio_cookies.txt
curl -ksL -b $COOKIE -c $COOKIE -o /tmp/aio.html https://localhost:8181/
CN=$(grep -oE "name=\"csrf_name\" value=\"[^\"]+\"" /tmp/aio.html | head -1 | sed "s/.*value=\"//;s/\".*//")
CV=$(grep -oE "name=\"csrf_value\" value=\"[^\"]+\"" /tmp/aio.html | head -1 | sed "s/.*value=\"//;s/\".*//")

# Stop pour calmer les loops
docker stop nextcloud-aio-database nextcloud-aio-redis nextcloud-aio-collabora

# Update master (entraîne son redémarrage)
curl -ks -b $COOKIE --max-time 300 -X POST https://localhost:8181/api/docker/watchtower \
  --data-urlencode "csrf_name=$CN" --data-urlencode "csrf_value=$CV"

# Attendre que le master redevienne healthy
sleep 60
docker ps --filter name=nextcloud-aio-mastercontainer --format "{{.Status}}"
'
```

Puis refaire l'étape 3.2 (re-login + start) car le master a redémarré et invalidé les cookies.

### 3.4 Si `nextcloud-aio-nextcloud` ou `nextcloud-aio-apache` part en restart loop

Incident 8.4 du troubleshooting. Symptômes au log :
- nextcloud-aio-nextcloud : `CastHelper.php line 20: Non-numeric value specified` (commande `occ config:system:set loglevel`).
- nextcloud-aio-apache : `Format string '%(ENV_AIO_LOG_LEVEL)s' for 'supervisord.loglevel' contains names which cannot be expanded`.

**Cause** : la variable d'env `AIO_LOG_LEVEL` n'est pas dans la config du conteneur. Le master ne la pousse pas via `docker start` sur un conteneur préexistant — uniquement via `docker create` quand il en spawne un nouveau.

**Correctif (solution simple)** : forcer la recréation des conteneurs :
```bash
ssh homelab '
docker stop nextcloud-aio-nextcloud nextcloud-aio-apache 2>/dev/null
docker rm nextcloud-aio-nextcloud nextcloud-aio-apache
# Refaire étape 3.2 (login + POST /api/docker/start)
'
```

Le master appelle `docker create` (et non `docker start`) sur les conteneurs absents, ce qui pousse les bonnes variables d'env. Vérifier après :
```bash
ssh homelab '
docker inspect nextcloud-aio-apache --format "{{range .Config.Env}}{{println .}}{{end}}" | grep AIO_LOG_LEVEL
# attendu : AIO_LOG_LEVEL=warn
docker inspect nextcloud-aio-nextcloud --format "restarts={{.RestartCount}} health={{.State.Health.Status}}"
# attendu : restarts=0 health=healthy
'
```

**Fallback si la solution simple échoue** : patch local des images (entrypoint.sh + supervisord.conf), cf section 8.4 de [[homelab-troubleshooting]].

## Étape 4 — Vérifications finales

### 4.1 Tous les conteneurs healthy

```bash
ssh homelab 'docker ps -a --format "{{.Names}}: {{.Status}}" | grep -vE "Up.*\(healthy\)|Exited \(0\).*watchtower"'
```

Sortie attendue : vide (tout est up healthy, sauf le watchtower AIO qui exit normalement après son job).

### 4.2 Accessibilité externe

```bash
# LADTC public (via Cloudflare)
curl -sIL https://ladtc.be/ --max-time 10 | head -3

# Nextcloud public
curl -sIL https://cloud.anthemion.dev/ --max-time 10 | head -3

# Coolify (si exposé)
curl -sIL https://coolify.anthemion.dev/ --max-time 10 | head -3
```

Attendre HTTP 200 ou 302 (redirect login). Un 502 indique qu'un service interne ne répond pas encore — réessayer dans 30s.

### 4.3 Sauvegardes et services système

```bash
ssh homelab '
systemctl is-active docker nut-server nut-monitor cloudflared fail2ban ufw
df -h /mnt/nas/* | grep -v Sys
upsc eaton@localhost | grep -E "ups.status|battery.charge"
'
```

Vérifier :
- Tous services `active`.
- NFS monts `/mnt/nas/*` montés et lisibles.
- UPS `ups.status: OL` et batterie > 90 %.

## Étape 5 — Documentation post-incident

À chaque application de cette procédure, **mettre à jour la Daily du jour** ([[Daily/]]) avec :
- Heure de la coupure et heure de remise en service.
- Conteneurs concernés (lesquels ont nécessité un redeploy Coolify, lesquels ont nécessité un patch image).
- Toute nouvelle erreur rencontrée non documentée dans [[homelab-troubleshooting]] — l'ajouter à la note.

## Roadmap d'amélioration

- [ ] **Automatiser l'étape 1** via un script systemd-oneshot lancé après `docker.service` qui force `docker start` sur une liste hardcodée. À écrire dans `/usr/local/bin/homelab-post-boot.sh`.
- [ ] **Automatiser l'étape 3.2** (start AIO) via cron post-boot si le caisson reste sur secteur direct. Le password en clair dans un script root-only est acceptable vu le contexte single-user.
- [ ] **Tester l'UPS Eaton Ellipse PRO 1600** : déclencher une coupure simulée pour confirmer que NUT shutdown proprement le système avant épuisement batterie. Configurer `BATTERYLEVEL` dans `upsmon.conf`.
- [ ] **Surveiller le bug AIO upstream** (8.4) : retirer le patch local dès que l'image officielle est rebuild avec le fix `--value="2"`.
- [ ] **Pinner les images AIO** sur un digest stable plutôt que `:latest` pour éviter les régressions watchtower futures (réfléchir au tradeoff sécurité/stabilité).
