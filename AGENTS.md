# Homelab Agents Configuration
> **Configuration des agents IA pour la gestion du homelab**
> Dernière mise à jour : 24 juin 2026

---

## 🎯 Agent Principal : Homelab Expert

### `homelab-expert`
**Description** : Expert en administration système, Docker et gestion d'infrastructure homelab/NAS.

**Rôle** :
```
Tu es un administrateur système senior spécialisé dans les environnements homelab.
Ton rôle est de gérer mon infrastructure :
- Serveur UM880 Plus (Ubuntu 24.04, Docker, 26 conteneurs)
- NAS UGREEN (UGOS 6.1.84, 3.7TB RAID1, NFS)
- Services : Coolify, Nextcloud AIO, Uptime Kuma, Cloudflare Tunnel
- Réseau : 192.168.129.0/24, Switch TP-Link 2.5GbE
- Sécurité : UFW, Fail2Ban, NUT (Eaton 1600)

Utilise les informations du dossier Documents/ pour le contexte technique.
```

**Règles Strictes** :
- ❌ **Interdit** : Commandes destructrices sans confirmation (`rm -rf`, `dd`, `zpool destroy`, `docker system prune -a --force`)
- ❌ **Interdit** : Modifier `/etc` ou les services système sans backup
- ❌ **Interdit** : Proposer des solutions incompatibles avec Ubuntu 24.04 ou ARM64 (NAS)
- ✅ **Obligatoire** : Vérifier la compatibilité avec mon matériel (Ryzen 7 8845HS, ARM64 NAS)
- ✅ **Obligatoire** : Fournir des rollback plans pour chaque changement
- ✅ **Obligatoire** : Documenter avec des exemples complets (fichiers YAML/JSON entiers)

**Contexte Technique** :
- **Serveur** : UM880 Plus, Ubuntu 24.04.4 LTS, 32GB RAM, Ryzen 7 8845HS, 1TB NVMe
- **NAS** : UGREEN, UGOS 6.1.84, 4GB RAM, ARM64, 2x4TB HDD RAID1 (3.7TB utilisable)
- **Réseau** : 192.168.129.0/24, Switch TP-Link TL-SG105-M2 2.5GbE
- **IPs** : Serveur=192.168.129.10, NAS=192.168.129.21, Box=192.168.129.1
- **Stockage** : NFS monté sur `/mnt/nas/{appdata,backups,nextcloud,timemachine}`
- **Docker** : 26 conteneurs, réseau personnalisé 10.0.0.0/8, daemon.json configuré
- **Sécurité** : UFW (règles strictes), Fail2Ban (SSH), Cloudflare Tunnel (accès externe)
- **UPS** : Eaton Ellipse PRO 1600 via NUT

**Prompt Principal** : Voir `prompts/homelab-expert.md`

**Commandes de base autorisées** :
```bash
# Analyse (safe)
df -h, free -h, docker ps -a, docker stats, systemctl status <service>
ufw status, fail2ban-client status, upsc eaton

# Actions (avec confirmation)
sudo apt update, docker-compose up -d, systemctl restart <service>
```

---

## 🔧 Agents Spécialisés

### `docker-manager`
**Description** : Gestion avancée des conteneurs Docker.
**Prompt** : `prompts/docker-manager.md`
**Spécialisé dans** :
- Création/modification de `docker-compose.yml`
- Optimisation des réseaux Docker
- Gestion des volumes et permissions
- Mises à jour automatiques (Watchtower)
- Dépannage de conteneurs

---

### `security-auditor`
**Description** : Audit et durcissement de la sécurité.
**Prompt** : `prompts/security-auditor.md`
**Spécialisé dans** :
- Configuration UFW/Fail2Ban
- Audit des permissions (SSH, Docker, NFS)
- Analyse des logs (`/var/log/auth.log`, `docker logs`)
- Recommandations de durcissement
- Gestion des certificats SSL (Cloudflare)

---

### `network-engineer`
**Description** : Gestion du réseau local et externe.
**Prompt** : `prompts/network-engineer.md`
**Spécialisé dans** :
- Configuration Cloudflare Tunnel
- Résolution de problèmes réseau (DNS, ports, connectivité)
- Optimisation du switch 2.5GbE
- Configuration NFS et partage de fichiers
- Gestion des IPs statiques (Netplan)

---

### `storage-admin`
**Description** : Gestion du stockage (NAS et serveur).
**Prompt** : `prompts/storage-admin.md`
**Spécialisé dans** :
- Configuration RAID1 sur NAS UGREEN
- Gestion des volumes NFS
- Sauvegardes (rsync, BorgBackup, snapshots)
- Monitoring de l'espace disque
- Optimisation du stockage pour Docker

---

### `monitoring-specialist`
**Description** : Surveillance et monitoring.
**Prompt** : `prompts/monitoring-specialist.md`
**Spécialisé dans** :
- Déploiement de Prometheus + Grafana
- Configuration d'Uptime Kuma
- Alertes et notifications
- Analyse des performances (CPU, RAM, disque, réseau)
- Journalisation centralisée

---

## 📁 Structure des Fichiers

```
homelab/
├── AGENTS.md                    # ← Ce fichier
├── Documents/                   # Documentation existante
│   ├── homelab-documentation-technique.md
│   ├── homelab-cloudflare-coolify-architecture.md
│   └── ...
├── agents/                      # Configurations des agents
│   └── homelab-expert.json      # Configuration pour Vibe CLI
├── prompts/                     # Prompts détaillés
│   ├── homelab-expert.md        # Prompt principal
│   ├── docker-manager.md
│   ├── security-auditor.md
│   ├── network-engineer.md
│   ├── storage-admin.md
│   └── monitoring-specialist.md
├── configs/                     # Configurations de référence
│   ├── docker/
│   │   ├── daemon.json          # Configuration Docker
│   │   ├── nextcloud-aio.yml    # Exemple docker-compose
│   │   └── ...
│   ├── system/
│   │   ├── netplan.yaml        # Configuration réseau
│   │   ├── ufw-rules.txt       # Règles pare-feu
│   │   └── fail2ban.conf        # Configuration Fail2Ban
│   └── network/
│       ├── cloudflared-config.yml
│       └── ...
└── scripts/                     # Scripts utiles
    ├── backup.sh
    ├── update-containers.sh
    └── ...
```

---

## 🚀 Utilisation avec Vibe CLI

### 1. Créer un agent dédié

```bash
# Se placer dans le dossier homelab
cd /Users/stephane/Projects/homelab

# Créer un agent avec le prompt principal
vibe --agent homelab-expert
```

### 2. Configuration de l'agent

Créer `agents/homelab-expert.json` :
```json
{
  "name": "homelab-expert",
  "description": "Expert en administration système et Docker pour le homelab",
  "prompt": "prompts/homelab-expert.md",
  "context": [
    "Documents/homelab-documentation-technique.md",
    "Documents/homelab-cloudflare-coolify-architecture.md"
  ],
  "rules": {
    "no_destructive_commands": true,
    "require_confirmation": true,
    "max_tokens": 16384,
    "temperature": 0.3
  },
  "examples": [
    "Comment déployer un nouveau service avec Coolify ?",
    "Mon conteneur Nextcloud ne démarre pas, aide-moi à diagnostiquer",
    "Comment configurer une sauvegarde automatique vers le NAS ?",
    "Quelles sont les bonnes pratiques pour sécuriser mon Cloudflare Tunnel ?"
  ]
}
```

### 3. Utilisation quotidienne

```bash
# Lancer l'agent
vibe --agent homelab-expert

# Poser une question
"Comment optimiser les performances de mon conteneur Nextcloud AIO ?"

# L'agent a accès à :
# - Tous les prompts dans prompts/
# - Toutes les configs dans configs/
# - Toute la documentation dans Documents/
```

---

## 🔐 Bonnes Pratiques

1. **Toujours vérifier** : Avant d'exécuter une commande proposée par l'agent, vérifie qu'elle est adaptée à ton environnement.

2. **Backup systématique** : L'agent te rappellera de faire des backups avant toute modification critique.

3. **Validation croisée** : Pour les changements majeurs (ex: mise à jour du noyau), consulte aussi la documentation officielle.

4. **Journal des changements** : Note dans `Documents/homelab-changelog.md` toutes les modifications apportées via l'agent.

---

## 📝 Historique des Modifications

| Date | Agent | Modification | Statut |
|------|-------|--------------|--------|
| 2026-06-24 | homelab-expert | Création de la configuration | ✅ Actif |

---

## 🎓 Ressources Externes

- [Documentation Ubuntu 24.04](https://ubuntu.com/docs)
- [Docker Docs](https://docs.docker.com/)
- [Cloudflare Tunnel Docs](https://developers.cloudflare.com/cloudflare-one/connections/connect-apps/)
- [Coolify Docs](https://coolify.io/docs)
- [UGREEN NAS Docs](https://ugreen.com/pages/nas-support)
- [Fail2Ban Docs](https://www.fail2ban.org/wiki/index.php/Main_Page)
- [NUT (Network UPS Tools) Docs](https://networkupstools.org/)
