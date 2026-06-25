# Configurations Docker pour le Homelab

> **Dernière mise à jour** : 24 juin 2026
> **Environnement** : Ubuntu 24.04.4 LTS sur UM880 Plus

---

## 📁 Fichiers de Configuration

| Fichier | Description | Applicable à |
|--------|-------------|--------------|
| [`daemon.json`](daemon.json) | Configuration du daemon Docker | Serveur UM880 |
| [`caddy.yml`](caddy.yml) + [`Caddyfile`](Caddyfile) | Reverse proxy HTTPS avec Let's Encrypt | NAS Ugreen |
| [`nextcloud-aio.yml`](nextcloud-aio.yml) | Configuration Nextcloud AIO | Serveur UM880 |
| [`coolify.yml`](coolify.yml) | Configuration Coolify | Serveur UM880 |
| [`uptime-kuma.yml`](uptime-kuma.yml) | Configuration Uptime Kuma | Serveur UM880 |
| [`networks.md`](networks.md) | Réseaux Docker personnalisés | Serveur UM880 |

---

## 🌐 Caddy - Reverse Proxy HTTPS

### Emplacement

**NAS Ugreen** : `/home/Steph/caddy/`

### Architecture

```
Internet → Port 80/443 (NAS) → Caddy Container → Services locaux
```

### Services routés

| Sous-domaine | Port local | Service |
|-------------|-----------|---------|
| `stephaneroos.com` | - | Redirect → `home.stephaneroos.com` |
| `www.stephaneroos.com` | - | Redirect → `stephaneroos.com` |
| `photos.stephaneroos.com` | 8080 | Nextcloud Photos / Immich |
| `cloud.stephaneroos.com` | 8082 | Nextcloud Personal |
| `home.stephaneroos.com` | 4000 | Dashy (portail) |
| `git.stephaneroos.com` | 3000 | Forgejo |

### Déploiement

```bash
# Sur le NAS
cd /home/Steph/caddy
docker compose up -d

# Recharger la configuration (sans downtime)
docker exec caddy caddy reload --config /etc/caddy/Caddyfile

# Voir les logs
docker logs -f caddy
```

### Certificats Let's Encrypt

Caddy génère automatiquement les certificats HTTPS via Let's Encrypt.

**Prérequis** :
- DNS A records pour chaque sous-domaine → IP publique du NAS
- Port forwarding 80/443 TCP vers NAS (192.168.129.21)
- Ports 80/443 libres sur le NAS (nginx/webdav désactivés)

### Maintenance

```bash
# Arrêter
docker compose down

# Mettre à jour
docker compose pull
docker compose up -d

# Vérifier la configuration
docker exec caddy caddy validate --config /etc/caddy/Caddyfile
```

### Services système désactivés

Pour libérer les ports 80/443, les services suivants ont été désactivés sur le NAS :
- `nginx.service` - Web serveur système
- `webdav.service` - Serveur WebDAV NAS
- `apache2.service` - Non installé

Pour réactiver (si besoin) :
```bash
sudo systemctl enable nginx webdav
sudo systemctl start nginx webdav
docker compose -f /home/Steph/caddy/docker-compose.yml down
```

---

## 🔧 Configuration du Daemon Docker

### Fichier : `daemon.json`

**Emplacement** : `/etc/docker/daemon.json`

**Appliquer la configuration** :
```bash
# Copier le fichier
sudo cp /Users/stephane/Projects/homelab/configs/docker/daemon.json /etc/docker/daemon.json

# Redémarrer Docker
sudo systemctl restart docker

# Vérifier le statut
sudo systemctl status docker
```

**Explications des paramètres** :

| Paramètre | Valeur | Description |
|-----------|--------|-------------|
| `log-driver` | `json-file` | Driver de logging par défaut |
| `log-opts.max-size` | `10m` | Taille max des logs par conteneur |
| `log-opts.max-file` | `3` | Nombre max de fichiers de log |
| `default-address-pools` | `10.0.0.0/8` | Plage d'IP pour les réseaux Docker (évite les conflits avec le réseau local) |
| `ip` | `127.0.0.1` | Le daemon Docker écoute uniquement sur localhost (sécurité) |
| `iptables` | `true` | Utilise iptables pour le NAT |
| `ip-masq` | `true` | Masquerade IP pour les conteneurs |
| `userland-proxy` | `false` | Désactive le proxy userland (meilleures performances) |
| `no-new-privileges` | `true` | Empêche l'escalade de privilèges |
| `live-restore` | `true` | Permet la restauration des conteneurs après redémarrage de Docker |
| `default-ulimits.nofile` | `65536` | Limite le nombre de fichiers ouverts |
| `features.buildkit` | `true` | Active BuildKit (meilleures performances de build) |

---

## 🌐 Réseaux Docker

### Réseaux existants

| Réseau | Driver | Subnet | Utilisation |
|--------|--------|--------|-------------|
| `bridge` | bridge | 172.17.0.0/16 | Réseau par défaut |
| `host` | host | - | Accès direct à l'hôte |
| `none` | null | - | Pas de réseau |

### Réseaux personnalisés recommandés

**Pour isoler les services** :

1. **Réseau pour les services web** :
```bash
docker network create --driver=bridge --subnet=10.0.1.0/24 --gateway=10.0.1.1 web_network
```

2. **Réseau pour les bases de données** :
```bash
docker network create --driver=bridge --subnet=10.0.2.0/24 --gateway=10.0.2.1 db_network
```

3. **Réseau pour les services internes** :
```bash
docker network create --driver=bridge --subnet=10.0.3.0/24 --gateway=10.0.3.1 internal_network
```

**Vérifier les réseaux** :
```bash
docker network ls
```

---

## 🔒 Bonnes Pratiques Docker

### 1. Sécurité

✅ **Toujours faire** :
- Utiliser des **users non-root** dans les conteneurs
- Limiter les **capabilities** Docker
- Monter `/var/run/docker.sock` en **lecture seule** (`:ro`)
- Utiliser des **réseaux dédiés** pour isoler les services
- Configurer des **limites de ressources** (CPU, RAM)

❌ **À éviter** :
- Exécuter des conteneurs avec `--privileged`
- Utiliser `--net=host` sans nécessité
- Monter `/etc`, `/usr`, `/var` dans les conteneurs
- Exposer des ports inutiles

### 2. Performances

- **Limiter la RAM** :
  ```yaml
  deploy:
    resources:
      limits:
        memory: 2G
  ```

- **Limiter le CPU** :
  ```yaml
  deploy:
    resources:
      limits:
        cpus: '1.0'
  ```

- **Utiliser des volumes nommés** plutôt que des bind mounts pour les données persistantes

### 3. Maintenance

**Nettoyage régulier** :
```bash
# Supprimer les conteneurs stoppés
docker container prune

# Supprimer les images non utilisées
docker image prune

# Supprimer les volumes orphelins
docker volume prune

# Supprimer les réseaux inutilisés
docker network prune

# Tout nettoyer (ATTENTION : destructif)
docker system prune -a
```

**Mises à jour** :
```bash
# Mettre à jour une image
docker pull <image>:<tag>

# Redémarrer les conteneurs avec la nouvelle image
docker-compose up -d --force-recreate
```

---

## 📚 Documentation Complémentaire

- [Docker Official Docs](https://docs.docker.com/)
- [Docker Compose Spec](https://docs.docker.com/compose/compose-file/)
- [Docker Security](https://docs.docker.com/engine/security/)
- [LinuxServer.io Guides](https://docs.linuxserver.io/) - Images Docker bien configurées
