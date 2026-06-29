# Réseaux Docker pour le Homelab

> **Dernière mise à jour** : 24 juin 2026
> **Environnement** : Ubuntu 24.04.4 LTS sur UM880 Plus

---

## 🌐 Architecture Réseau Docker

### Réseaux existants

| Réseau | Type | Subnet | Utilisation |
|--------|------|--------|-------------|
| `bridge` | bridge | 172.17.0.0/16 | Réseau par défaut pour les conteneurs sans réseau spécifique |
| `host` | host | - | Accès direct à l'hôte (à éviter pour la sécurité) |
| `none` | null | - | Pas de réseau |

### Réseaux personnalisés recommandés

Pour une **meilleure sécurité et isolation**, crée des réseaux Docker dédiés :

---

## 🔧 Création des Réseaux

### 1. Réseau pour les services web (exposés via Cloudflare)

```bash
# Créer le réseau
docker network create \
  --driver=bridge \
  --subnet=10.0.1.0/24 \
  --gateway=10.0.1.1 \
  --opt com.docker.network.bridge.name=br-web \
  web_network

# Vérifier
docker network inspect web_network
```

**Utilisation** : Coolify, Uptime Kuma, Nextcloud (si accès web direct)

---

### 2. Réseau pour les bases de données

```bash
# Créer le réseau
docker network create \
  --driver=bridge \
  --subnet=10.0.2.0/24 \
  --gateway=10.0.2.1 \
  --opt com.docker.network.bridge.name=br-db \
  db_network

# Vérifier
docker network inspect db_network
```

**Utilisation** : PostgreSQL, Redis, MySQL, MariaDB

---

### 3. Réseau pour les services internes

```bash
# Créer le réseau
docker network create \
  --driver=bridge \
  --subnet=10.0.3.0/24 \
  --gateway=10.0.3.1 \
  --internal \  # Réseau isolé (pas d'accès extérieur)
  --opt com.docker.network.bridge.name=br-internal \
  internal_network

# Vérifier
docker network inspect internal_network
```

**Utilisation** : Services qui ne doivent pas être accessibles depuis l'extérieur (ex: admin, backup)

---

### 4. Réseau pour le monitoring

```bash
# Créer le réseau
docker network create \
  --driver=bridge \
  --subnet=10.0.4.0/24 \
  --gateway=10.0.4.1 \
  --opt com.docker.network.bridge.name=br-monitoring \
  monitoring_network
```

**Utilisation** : Prometheus, Grafana, Node Exporter

---

## 📋 Liste Complète des Réseaux

```bash
# Lister tous les réseaux
docker network ls

# Exemple de sortie :
# NETWORK ID     NAME              DRIVER    SCOPE
# a1b2c3d4e5f6   bridge            bridge    local
# 7f8e9d0c1b2a   host              host      local
# 9c8b7a6f5e4d   none              null      local
# 1a2b3c4d5e6f   web_network       bridge    local
# 2b3c4d5e6f7a   db_network        bridge    local
# 3c4d5e6f7a8b   internal_network  bridge    local
# 4d5e6f7a8b9c   monitoring_network bridge local
```

---

## 🔍 Inspection des Réseaux

### Voir les détails d'un réseau

```bash
docker network inspect web_network
```

**Exemple de sortie** :
```json
{
    "Name": "web_network",
    "Driver": "bridge",
    "Subnet": "10.0.1.0/24",
    "Gateway": "10.0.1.1",
    "IPAM": {
        "Driver": "default",
        "Config": [{
            "Subnet": "10.0.1.0/24",
            "Gateway": "10.0.1.1"
        }]
    },
    "Containers": {
        "coolify": {
            "IPv4Address": "10.0.1.2/24",
            "IPv6Address": ""
        },
        "uptime-kuma": {
            "IPv4Address": "10.0.1.3/24",
            "IPv6Address": ""
        }
    }
}
```

---

## 🔄 Gestion des Réseaux

### Connecter un conteneur à un réseau

```bash
# Connecter un conteneur existant à un réseau
docker network connect web_network coolify

# Vérifier les connexions d'un conteneur
docker inspect coolify | grep -i network
```

### Déconnecter un conteneur d'un réseau

```bash
# Déconnecter un conteneur d'un réseau
docker network disconnect web_network coolify
```

### Supprimer un réseau

```bash
# Supprimer un réseau (doit être vide)
docker network rm web_network

# Forcer la suppression (même s'il y a des conteneurs)
docker network rm web_network --force
```

---

## 🔒 Bonnes Pratiques de Sécurité

### 1. Isolation des services

✅ **Faire** :
- Créer un **réseau dédié par type de service** (web, db, monitoring)
- Utiliser des **réseaux internes** (`--internal`) pour les services sensibles
- **Limiter les connexions** entre réseaux avec des règles de pare-feu

❌ **À éviter** :
- Mettre tous les services sur le **réseau bridge par défaut**
- Utiliser le **réseau host** sans nécessité absolue
- Connecter des conteneurs à **trop de réseaux**

### 2. Configuration des conteneurs

**Exemple avec docker-compose** :

```yaml
version: '3.8'

services:
  webapp:
    image: nginx:latest
    networks:
      - web_network
      - db_network  # Se connecte aux deux réseaux
    
  database:
    image: postgres:15
    networks:
      - db_network  # Uniquement sur le réseau db
    # Pas d'accès au réseau web

networks:
  web_network:
    external: true
  db_network:
    external: true
```

### 3. Communication entre réseaux

**Pour autoriser la communication entre réseaux** :

```bash
# Connecter deux réseaux via un routeur (conteneur)
docker run -d \
  --name=network-router \
  --network=web_network \
  --network=db_network \
  nginx:latest
```

---

## 📊 Monitoring des Réseaux

### Voir le trafic réseau

```bash
# Voir les connexions actives
docker network inspect web_network | grep -A 10 Containers

# Voir les statistiques de trafic (nécessite des outils supplémentaires)
docker stats --no-stream
```

### Outils de monitoring

1. **Netdata** : Monitoring en temps réel
2. **cAdvisor** : Monitoring des conteneurs
3. **Prometheus + Grafana** : Surveillance avancée

---

## 🚀 Exemple Complet : Stack avec Réseaux Isolés

Voici un exemple complet avec plusieurs services sur différents réseaux :

```yaml
version: '3.8'

# Définition des réseaux
networks:
  web_network:
    driver: bridge
    ipam:
      config:
        - subnet: 10.0.1.0/24
          gateway: 10.0.1.1
  db_network:
    driver: bridge
    internal: true  # Réseau isolé
    ipam:
      config:
        - subnet: 10.0.2.0/24
          gateway: 10.0.2.1
  monitoring_network:
    driver: bridge
    ipam:
      config:
        - subnet: 10.0.4.0/24
          gateway: 10.0.4.1

services:
  # Service Web
  webapp:
    image: nginx:latest
    container_name: webapp
    restart: unless-stopped
    networks:
      - web_network
    ports:
      - "127.0.0.1:80:80"
    deploy:
      resources:
        limits:
          memory: 256M

  # Base de données
  postgres:
    image: postgres:15
    container_name: postgres
    restart: unless-stopped
    networks:
      - db_network
    volumes:
      - postgres_data:/var/lib/postgresql/data
    environment:
      POSTGRES_PASSWORD: ${DB_PASSWORD}
    deploy:
      resources:
        limits:
          memory: 1G

  # Application (accède à la DB et expose un API)
  app:
    image: myapp:latest
    container_name: app
    restart: unless-stopped
    networks:
      - web_network
      - db_network
    environment:
      DB_HOST: postgres
      DB_PORT: 5432
      DB_PASSWORD: ${DB_PASSWORD}
    depends_on:
      - postgres
    deploy:
      resources:
        limits:
          memory: 512M

  # Monitoring
  prometheus:
    image: prom/prometheus:latest
    container_name: prometheus
    restart: unless-stopped
    networks:
      - monitoring_network
    volumes:
      - prometheus_data:/prometheus
      - ./prometheus.yml:/etc/prometheus/prometheus.yml
    ports:
      - "127.0.0.1:9090:9090"

volumes:
  postgres_data:
  prometheus_data:
```

---

## 🔧 Dépannage Réseau

### Problème : Les conteneurs ne peuvent pas communiquer

**Diagnostic** :

1. Vérifier que les conteneurs sont sur le même réseau :
   ```bash
   docker network inspect <réseau> | grep -A 20 Containers
   ```

2. Tester la connectivité depuis un conteneur :
   ```bash
   docker exec -it <conteneur> ping <autre-conteneur>
   docker exec -it <conteneur> curl -I http://<autre-conteneur>:<port>
   ```

3. Vérifier les IPs des conteneurs :
   ```bash
   docker inspect <conteneur> | grep IPAddress
   ```

**Solutions** :

- **Les conteneurs ne sont pas sur le même réseau** :
  ```bash
  docker network connect <réseau> <conteneur>
  ```

- **Le conteneur cible n'écoute pas sur le bon port** :
  ```bash
  docker exec -it <conteneur-cible> netstat -tulnp
  ```

- **Problème de DNS** :
  - Utiliser l'IP du conteneur au lieu du nom
  - Ou configurer un DNS personnalisé

---

### Problème : Pas de connexion internet depuis un conteneur

**Diagnostic** :

```bash
# Tester depuis le conteneur
docker exec -it <conteneur> ping 8.8.8.8

# Vérifier la configuration réseau du conteneur
docker inspect <conteneur> | grep -i network
```

**Solutions** :

- **Le conteneur est sur un réseau interne** :
  - Créer un nouveau réseau sans `--internal`
  - Ou connecter le conteneur à un réseau avec accès internet

- **Problème de DNS** :
  ```bash
  docker exec -it <conteneur> cat /etc/resolv.conf
  ```
  - Vérifier que les serveurs DNS sont corrects

---

## 📚 Documentation Complémentaire

- [Docker Networking Docs](https://docs.docker.com/network/)
- [Docker Compose Networking](https://docs.docker.com/compose/networking/)
- [Docker Network Drivers](https://docs.docker.com/network/drivers/)
- [Best Practices for Docker Networking](https://docs.docker.com/engine/userguide/networking/best-practices/)

---

## 💡 Conseils pour le Homelab

1. **Utilise des réseaux dédiés** pour chaque type de service
2. **Isole les bases de données** dans un réseau interne
3. **Évite le réseau host** sauf pour des raisons de performance critiques
4. **Documente ta topologie réseau** pour faciliter le dépannage
5. **Monitorer le trafic réseau** entre les conteneurs
6. **Utilise des VLANs** si ton switch le permet (pour une isolation physique)
7. **Sécurise les réseaux internes** avec des règles de pare-feu Docker
