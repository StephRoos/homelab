# Plan de Migration : Cloudflare Tunnel → Caddy

> **Objectif** : Remplacer Cloudflare Tunnel par Caddy comme reverse proxy
> **Approche** : Migration progressive avec rollback à chaque étape
> **Durée estimée** : 2-3 heures (plus temps DNS propagation)

---

> ⚠ **MISE À JOUR 2026-06-28 — Plan partiellement abandonné.**
> Ce document décrivait le remplacement **total** de Cloudflare Tunnel par
> Caddy (Caddy direct + Let's Encrypt, donc port forwarding 80/443 box → NAS).
> Or il n'y a **pas de port forwarding** sur la box (seul le hairpin NAT trompe
> les tests lancés depuis le LAN), donc Caddy ne peut pas obtenir de certificat
> Let's Encrypt et ce plan ne fonctionne pas tel quel.
>
> **Architecture réelle retenue à la place :**
> - **Cloudflare Tunnel conservé** pour le public (`anthemion.dev`, `ladtc.be`…)
>   — chaque hostname pointe **directement** vers son conteneur (port host
>   loopback publié ou IP Docker), sans passer par Caddy.
> - **Caddy en HTTP-only** (`auto_https off`) pour le perso `stephaneroos.com`
>   (`git`, `photos`) — le TLS est terminé à l'edge Cloudflare via le tunnel.
> - `stephaneroos.com` (apex) + `www` → **Obsidian Publish**, pas Caddy.
>
> Référence à jour : [`incident-redirect-loop-2026-06-28.md`](./incident-redirect-loop-2026-06-28.md)
> (diagnostic complet, cartographie finale du tunnel, runbook). La suite du
> présent document reste un **brouillon historique**.

---

## Table des matières

1. [État des lieux](#état-des-lieux)
2. [Architecture cible](#architecture-cible)
3. [Prérequis](#prérequis)
4. [Phase 0 : Préparation & Backup](#phase-0--préparation--backup)
5. [Phase 1 : Installation Caddy (parallèle)](#phase-1--installation-caddy-parallèle)
6. [Phase 2 : Tests internes](#phase-2--tests-internes)
7. [Phase 3 : Migration DNS (service par service)](#phase-3--migration-dns-service-par-service)
8. [Phase 4 : Désactivation Cloudflare Tunnel](#phase-4--désactivation-cloudflare-tunnel)
9. [Phase 5 : Nettoyage](#phase-5--nettoyage)
10. [Rollback plan](#rollback-plan)

---

## État des lieux

### Services actuels via Cloudflare Tunnel

| Sous-domaine | Service | Port local | DNS actuel |
|--------------|---------|------------|------------|
| coolify.tondomain.com | Coolify | 8000 | Cloudflare Tunnel |
| status.tondomain.com | Uptime Kuma | 3001 | Cloudflare Tunnel |
| cloud.tondomain.com | Nextcloud AIO | 11000 | Cloudflare Tunnel |
| photos.tondomain.com | Immich | 2283 | Cloudflare Tunnel |
| ladtc.be | LADTC (Next.js) | 3000 (via Coolify/Traefik) | Cloudflare (IPs 188.114.x.x) |

### Note sur LADTC

LADTC est une application Next.js 16 déployée via **Coolify**, qui utilise déjà **Traefik** comme reverse proxy interne.

**Architecture actuelle :**
```
Internet → Cloudflare DNS → Cloudflare Tunnel → Traefik (Coolify) → LADTC:3000
```

**Architecture cible (option A - recommandée) :**
```
Internet → DNS (A record) → Caddy → Traefik (Coolify) → LADTC:3000
```

**Architecture cible (option B - directe) :**
```
Internet → DNS (A record) → Caddy → LADTC:3000
```
*L'option B requiert de configurer Caddy directement avec les containers Coolify*

### Adresse IP publique du homelab

```bash
# À exécuter sur le serveur pour récupérer l'IP publique
curl -4 ifconfig.me
```

> **Note** : Cette IP sera nécessaire pour configurer les enregistrements DNS.

---

## Architecture cible

### Option A : Caddy + Traefik (recommandée pour Coolify)

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                   AVANT (Cloudflare Tunnel)                                  │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  Internet → Cloudflare DNS → Cloudflare Edge → cloudflared → Traefik → Apps │
│                                 ↓                                            │
│                            WAF + SSL (Cloudflare)                            │
└─────────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────────┐
│                   APRÈS - Option A (Caddy + Traefik)                         │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  Internet → DNS (A record) → Caddy → Traefik → Apps                        │
│                                       ↓                                      │
│                                 Let's Encrypt                               │
│                                                                             │
│  Avantages :                                                                 │
│  • Coolify continue à fonctionner normalement                               │
│  • Traefik gère le routing interne Coolify                                  │
│  • Migration transparente pour les apps Coolify                            │
│  • Caddy gère SSL/HTTPS externe                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

### Option B : Caddy direct (plus simple, plus performant)

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                   APRÈS - Option B (Caddy direct)                            │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  Internet → DNS (A record) → Caddy → Apps (containers directs)            │
│                                       ↓                                      │
│                                 Let's Encrypt                               │
│                                                                             │
│  Avantages :                                                                 │
│  • Une couche de moins (plus performant)                                    │
│  • Configuration centralisée dans Caddyfile                                 │
│  • Pas de dépendance à Traefik/Coolify pour le routing                      │
│                                                                             │
│  Inconvénients :                                                             │
│  • Coolify doit être configuré pour exposer les ports directement          │
│  • Plus de configuration manuelle pour chaque nouvelle app                 │
└─────────────────────────────────────────────────────────────────────────────┘
```

### Comparatif

| Critère | Option A (Caddy + Traefik) | Option B (Caddy direct) |
|---------|----------------------------|-------------------------|
| **Complexité** | ⭐⭐ Moyenne | ⭐⭐⭐ Élevée |
| **Performance** | ⭐⭐⭐⭐ Bonne | ⭐⭐⭐⭐⭐ Excellente |
| **Coolify** | ✅ Fonctionne nativement | ⚠️ Configuration requise |
| **Maintenance** | ✅ Faible | ⚠️ Modérée |
| **Rollback** | ✅ Facile | ⚠️ Plus complexe |

**Recommandation** : Commencer par l'**Option A** pour une migration en douceur, puis évaluer l'Option B si les performances sont critiques.

---

## Prérequis

### 1. Connaître ton IP publique

```bash
# Sur le serveur homelab
curl -4 ifconfig.me
# Note cette IP, elle sera utilisée pour les enregistrements DNS
```

### 2. Vérifier que les ports 80/443 ne sont pas utilisés

```bash
# Sur le serveur
sudo ss -tulnp | grep -E ':80|:443'
```

Si les ports sont occupés, noter quel service les utilise.

### 3. Avoir accès au panel Cloudflare

Pour modifier les enregistrements DNS.

---

## Phase 0 : Préparation & Backup

> **⚠️ IMPORTANT** : Cette phase crée un point de restauration

### 0.1 Backup configuration Cloudflare Tunnel

```bash
# Sur le serveur
sudo cp -r /etc/cloudflared ~/backup/cloudflared-$(date +%Y%m%d)
sudo systemctl status cloudflared > ~/backup/cloudflared-status-$(date +%Y%m%d).txt

# Lister les tunnels configurés
cloudflared tunnel list
cloudflared tunnel info <TUNNEL-ID> > ~/backup/tunnel-info-$(date +%Y%m%d).txt
```

### 0.2 Noter les routes actuelles

```bash
# Noter dans un fichier les routes configurées
cat > ~/backup/routes-avant-migration.txt << 'EOF'
Routes Cloudflare Tunnel actuelles :
- coolify.tondomain.com → localhost:8000 (Coolify)
- status.tondomain.com → localhost:3001 (Uptime Kuma)
- cloud.tondomain.com → localhost:11000 (Nextcloud AIO)
- photos.tondomain.com → localhost:2284 (Immich)
- ladtc.be → WordPress (port à vérifier)

Date: $(date)
EOF
```

### 0.3 Créer le répertoire Caddy

```bash
sudo mkdir -p /etc/caddy
sudo mkdir -p /var/log/caddy
sudo mkdir -p /var/www/caddy
```

---

## Phase 1 : Installation Caddy (parallèle)

> **Objectif** : Installer Caddy sans perturber Cloudflare Tunnel

### 1.1 Installer Caddy via Docker

```bash
# Sur le serveur
docker run -d \
  --name caddy \
  --restart unless-stopped \
  -p 127.0.0.1:8080:80 \
  -p 127.0.0.1:8443:443 \
  -v /etc/caddy:/etc/caddy \
  -v /var/log/caddy:/var/log/caddy \
  -v caddy_data:/data \
  caddy:latest
```

> **Note** : On utilise d'abord localhost pour tester, sans exposer publiquement.

### 1.2 Créer le Caddyfile initial

```bash
sudo nano /etc/caddy/Caddyfile
```

```caddyfile
# /etc/caddy/Caddyfile
# Configuration Caddy pour tests internes

# Health check pour vérifier que Caddy fonctionne
:8080 {
    respond /health "OK" 200
    respond / "Caddy is running!" 200
}

# Logs globals
{
    # Pour le moment, logs stdout
    # On activera les fichiers logs plus tard
}
```

### 1.3 Tester Caddy

```bash
# Depuis le serveur
curl http://localhost:8080/health
# Doit retourner "OK"

curl http://localhost:8080/
# Doit retourner "Caddy is running!"

# Vérifier les logs
docker logs caddy --tail 50
```

### 1.4 Redémarrer Caddy avec configuration complète

```bash
docker restart caddy
```

✅ **Checkpoint 1** : Caddy fonctionne sur localhost

---

## Phase 2 : Tests internes

> **Objectif** : Configurer tous les services et tester en interne

### 2.1 Créer le Caddyfile complet

```bash
sudo nano /etc/caddy/Caddyfile
```

```caddyfile
# /etc/caddy/Caddyfile
# Configuration complète pour migration

# ===========================================
# Options globales
# =======================================
{
    # Email pour Let's Encrypt (requis pour ACME)
    email stephane@stephaneroos.com

    # Mode ACME - on commencera avec des certifs de test
    # TODO: commenter pour la prod
    # acme_ca https://acme-v02.api.letsencrypt.org/directory

    # Logs
    log {
        output file /var/log/caddy/access.log
        format json
        level INFO
    }
}

# ===========================================
# COOLIFY
# ===========================================
coolify.tondomain.com {
    reverse_proxy localhost:8000

    # Security headers
    header {
        X-Frame-Options "SAMEORIGIN"
        X-Content-Type-Options "nosniff"
        Referrer-Policy "strict-origin-when-cross-origin"
    }

    log {
        output file /var/log/caddy/coolify.log
        format json
    }
}

# ===========================================
# UPTIME KUMA
# ===========================================
status.tondomain.com {
    reverse_proxy localhost:3001

    header {
        X-Frame-Options "SAMEORIGIN"
        X-Content-Type-Options "nosniff"
    }

    log {
        output file /var/log/caddy/status.log
        format json
    }
}

# ===========================================
# NEXTCLOUD AIO
# ===========================================
cloud.tondomain.com {
    reverse_proxy localhost:11000

    # Nextcloud specific headers
    header {
        X-Frame-Options "SAMEORIGIN"
        # Strict-Transport-Security "max-age=31536000; includeSubDomains"
        X-Content-Type-Options "nosniff"
    }

    # Maximum upload size
    reverse_proxy localhost:11000 {
        header_up X-Real-IP {remote_host}
        header_up X-Forwarded-For {remote_host}
        header_up X-Forwarded-Host {host}
    }

    log {
        output file /var/log/caddy/nextcloud.log
        format json
    }
}

# ===========================================
# IMMICH
# ===========================================
photos.tondomain.com {
    reverse_proxy localhost:2283

    # Immich requires specific headers
    reverse_proxy localhost:2283 {
        header_up Host {host}
        header_up X-Real-IP {remote_host}
        header_up X-Forwarded-For {remote_host}
        header_up X-Forwarded-Proto {scheme}
        header_up X-Forwarded-Host {host}
    }

    # Large upload support
    # Caddy gère cela automatiquement, pas besoin de client_max_body_size

    log {
        output file /var/log/caddy/immich.log
        format json
    }
}

# ===========================================
# LADTC.BE (Next.js via Coolify/Traefik)
# ===========================================
ladtc.be {
    # Option A : Via Traefik (Coolify)
    reverse_proxy traefik:80

    # Option B : Direct (si Coolify expose le port)
    # reverse_proxy localhost:3000

    # Next.js headers spécifiques
    header {
        X-Frame-Options "DENY"
        X-Content-Type-Options "nosniff"
        Referrer-Policy "strict-origin-when-cross-origin"
        # Next.js gère son propre CSP, on peut laisser Caddy ajouter la sienne
        # Content-Security-Policy "default-src 'self'; ..."
    }

    log {
        output file /var/log/caddy/ladtc.log
        format json
    }
}

# Sous-domaines Coolify (si utilisés)
*.ladtc.be {
    reverse_proxy traefik:80

    header {
        X-Frame-Options "SAMEORIGIN"
        X-Content-Type-Options "nosniff"
    }
}
```

### 2.2 Redémarrer Caddy

```bash
docker restart caddy
docker logs caddy --tail 100 -f
```

### 2.3 Tester chaque service en interne

```bash
# Modifier /etc/hosts pour tester
sudo nano /etc/hosts
```

Ajouter temporairement :
```
127.0.0.1 coolify.tondomain.com
127.0.0.1 status.tondomain.com
127.0.0.1 cloud.tondomain.com
127.0.0.1 photos.tondomain.com
```

Puis tester :
```bash
curl -I http://coolify.tondomain.com:8080
curl -I http://status.tondomain.com:8080
curl -I http://cloud.tondomain.com:8080
curl -I http://photos.tondomain.com:8080
```

### 2.4 Nettoyer /etc/hosts

```bash
sudo nano /etc/hosts
# Supprimer les lignes ajoutées
```

✅ **Checkpoint 2** : Tous les services répondent via Caddy en interne

---

## Phase 3 : Migration DNS (service par service)

> **Objectif** : Migrer un service à la fois vers Caddy

### 3.1 Ouvrir les ports 80/443 vers l'extérieur

```bash
# Configuration UFW
sudo ufw allow 80/tcp comment 'Caddy HTTP'
sudo ufw allow 443/tcp comment 'Caddy HTTPS'
sudo ufw status
```

### 3.2 Reconfigurer Caddy sur ports publics

```bash
# Arrêter Caddy
docker stop caddy
docker rm caddy

# Relancer avec ports publics
docker run -d \
  --name caddy \
  --restart unless-stopped \
  -p 80:80 \
  -p 443:443 \
  -v /etc/caddy:/etc/caddy \
  -v /var/log/caddy:/var/log/caddy \
  -v caddy_data:/data \
  caddy:latest

# Vérifier
docker logs caddy --tail 50
```

### 3.3 Changer DNS pour le PREMIER service (Coolify)

**Dans Cloudflare Dashboard :**

1. Aller dans DNS → Records
2. Pour `coolify.tondomain.com` :
   - **Avant** : CNAME pointing to `<tunnel-id>.cfargotunnel.com`
   - **Après** : A record pointing to `<TON_IP_PUBLIQUE>`

3. Désactiver le "Proxy orange" (☁️) → DNS only (⚪️ gris)

4. Cliquer Save

### 3.4 Attendre la propagation DNS (5-15 min)

```bash
# Vérifier la propagation
dig coolify.tondomain.com
# Doit retourner ton IP publique, pas Cloudflare

# Attendre que ce soit le cas, puis tester
curl -I https://coolify.tondomain.com
```

### 3.5 Valider HTTPS automatique

```bash
# Vérifier que Let's Encrypt a généré le certificat
docker exec caddy ls -la /data/caddy/certificates/

# Tester HTTPS
curl -Iv https://coolify.tondomain.com 2>&1 | grep -i ssl
```

✅ **Checkpoint 3a** : Coolify fonctionne via Caddy

### 3.6 Répéter pour chaque service

**Ordre recommandé :**

1. ✅ Coolify (le plus simple)
2. Status (Uptime Kuma)
3. Cloud (Nextcloud)
4. Photos (Immich)
5. Ladtc.be (WordPress) - en dernier

Pour chaque service :
1. Modifier le DNS dans Cloudflare
2. Attendre la propagation
3. Tester HTTPS
4. Valider que tout fonctionne
5. Passer au suivant

---

## Phase 4 : Désactivation Cloudflare Tunnel

> **Objectif** : Une fois tous les services migrés, retirer Cloudflare Tunnel

### 4.1 Vérifier que tout fonctionne

```bash
# Liste des services à tester
services=("coolify.tondomain.com" "status.tondomain.com" "cloud.tondomain.com" "photos.tondomain.com")

for service in "${services[@]}"; do
    echo "Testing $service..."
    curl -I https://$service | head -5
    echo "---"
done
```

### 4.2 Arrêter cloudflared

```bash
# Arrêter le service
sudo systemctl stop cloudflared

# Ne PAS désactiver encore (systemctl disable)
# On garde en cas de rollback
```

### 4.3 Attendre 24-48h

S'assurer que :
- Tous les services sont accessibles
- Les certificats SSL sont OK
- Aucune erreur dans les logs Caddy
- Le monitoring (Uptime Kuma) ne signale rien

### 4.4 Désactiver définitivement cloudflared

```bash
# Après 48h sans problème
sudo systemctl disable cloudflared
sudo systemctl status cloudflared

# Optionnel : désinstaller
# sudo apt remove cloudflared
```

---

## Phase 5 : Nettoyage

### 5.1 Supprimer les enregistrements Cloudflare obsolètes

Dans Cloudflare Dashboard :
- Supprimer les CNAME records pointing à `*.cfargotunnel.com`
- Garder les A records vers ton IP

### 5.2 Optimiser la configuration Caddy

```bash
# Vérifier les logs
tail -f /var/log/caddy/*.log

# Ajuster si nécessaire
sudo nano /etc/caddy/Caddyfile
docker restart caddy
```

### 5.3 Documenter la configuration finale

```bash
# Sauvegarder la config finale
cp /etc/caddy/Caddyfile ~/backup/caddy-final-$(date +%Y%m%d).conf
```

---

## Rollback Plan

> Si quelque chose ne va pas, voici comment revenir en arrière

### Rollback rapide (un service)

```bash
# Dans Cloudflare Dashboard :
# 1. Revenir au CNAME pointing au tunnel
# 2. Réactiver le proxy orange (☁️)
# 3. Sauvegarder

# Le service repasse par Cloudflare Tunnel immédiatement
```

### Rollback complet

```bash
# Sur le serveur
# 1. Arrêter Caddy
docker stop caddy

# 2. Redémarrer cloudflared
sudo systemctl start cloudflared
sudo systemctl enable cloudflared

# 3. Remettre tous les DNS en CNAME tunnel (dans Cloudflare Dashboard)

# 4. Vérifier
cloudflared tunnel list
curl -I https://coolify.tondomain.com
```

### Rollback DNS only

Si tu veux garder Caddy mais repasser par Cloudflare WAF/CDN :

```bash
# Dans Cloudflare Dashboard pour chaque domaine :
# 1. Garder l'A record vers ton IP
# 2. Activer le proxy orange (☁️)
# 3. Ajouter une règle Page Rule si nécessaire

# Le trafic ira : Internet → Cloudflare → Caddy → Services
```

---

## Checklist de validation

Avant de considérer la migration terminée :

- [ ] Tous les services sont accessibles via HTTPS
- [ ] Les certificats SSL sont valides (pas d'erreur navigateur)
- [ ] Les headers de sécurité sont appliqués
- [ ] Uptime Kuma ne signale aucune interruption
- [ ] Les logs Caddy ne montrent pas d'erreurs
- [ ] WordPress (ladtc.be) fonctionne correctement
- [ ] Nextcloud et Immich uploadent correctement
- [ ] Cloudflare Tunnel est arrêté depuis 48h
- [ ] La configuration finale est documentée

---

## Prochaines étapes post-migration

1. **Monitoring** : Configurer Grafana pour surveiller Caddy
2. **Sécurité** : Ajuster les fail2ban jails si nécessaire
3. **Performance** : Activer HTTP/3 dans Caddy
4. **Backup** : Automatiser les backups de `/etc/caddy` et `caddy_data`

---

## Notes importantes

1. **Let's Encrypt a des limits** : Ne pas recréer trop de certificats
2. **DNS prend du temps** : La propagation peut prendre jusqu'à 24h (rarement)
3. **Caddy gère SSL automatiquement** : Pas besoin de certbot
4. **Les logs sont essentiels** : Les surveiller pendant la migration
5. **Tester en interne d'abord** : Évite les problèmes publics

---

**Date de création** : 25 juin 2026
**Prévu pour** : Migration progressive avec rollback
**Durée estimée** : 2-3 heures + temps DNS
