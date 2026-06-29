# Prompts pour les Agents Homelab

> **Dernière mise à jour** : 24 juin 2026
> **Environnement** : UM880 Plus (Ubuntu 24.04) + NAS UGREEN (UGOS 6.1.84)

---

## 📁 Structure des Fichiers

```
prompts/
├── README.md                     # ← Ce fichier
├── homelab-expert.md            # Agent principal - Expert complet
├── docker-manager.md             # Agent spécialisé - Gestion Docker
├── security-auditor.md           # Agent spécialisé - Sécurité
├── network-engineer.md          # Agent spécialisé - Réseau
├── storage-admin.md              # Agent spécialisé - Stockage
└── monitoring-specialist.md      # Agent spécialisé - Monitoring
```

---

## 🎯 Agents Disponibles

### 1. `homelab-expert` - Agent Principal

**Fichier** : [`homelab-expert.md`](homelab-expert.md)

**Description** : Expert complet en administration système, Docker et gestion d'infrastructure homelab.

**Spécialités** :
- Conseil architectural
- Déploiement et configuration
- Maintenance et optimisation
- Dépannage
- Sécurité

**Utilisation** :
```bash
# Avec Vibe CLI
vibe --agent homelab-expert

# Ou fournir le prompt directement
vibe --prompt prompts/homelab-expert.md
```

**Exemples de questions** :
- "Comment déployer un nouveau service avec Docker ?"
- "Mon conteneur Nextcloud ne démarre pas, aide-moi"
- "Quelle est la meilleure stratégie de sauvegarde pour mon homelab ?"
- "Audit complet de la sécurité de mon infrastructure"

---

### 2. `docker-manager` - Expert Docker

**Fichier** : [`docker-manager.md`](docker-manager.md)

**Description** : Expert spécialisé dans la création, configuration, optimisation et dépannage des conteneurs Docker.

**Spécialités** :
- Déploiement de nouveaux conteneurs
- Configuration et optimisation
- Mises à jour automatiques
- Dépannage des conteneurs
- Sécurité Docker
- Gestion des données persistantes

**Utilisation** :
```bash
vibe --prompt prompts/docker-manager.md
```

**Exemples de questions** :
- "Crée-moi un docker-compose.yml pour Immich"
- "Comment optimiser les performances de mon conteneur Jellyfin ?"
- "Mon conteneur consomme trop de RAM, que faire ?"
- "Comment configurer Watchtower pour les mises à jour automatiques ?"

---

### 3. `security-auditor` - Expert Sécurité

**Fichier** : [`security-auditor.md`](security-auditor.md)

**Description** : Expert en audit, durcissement et protection de l'infrastructure.

**Spécialités** :
- Audit de sécurité complet
- Durcissement des configurations
- Protection contre les menaces
- Réponse aux incidents
- Monitoring de sécurité

**Utilisation** :
```bash
vibe --prompt prompts/security-auditor.md
```

**Exemples de questions** :
- "Fais un audit complet de la sécurité de mon homelab"
- "Comment durcir la configuration SSH ?"
- "Comment configurer Fail2Ban pour un nouveau service ?"
- "Je pense que mon serveur a été compromis, que faire ?"

---

### 4. `network-engineer` - Expert Réseau

**Fichier** : [`network-engineer.md`](network-engineer.md)

**Description** : Expert en configuration, optimisation et dépannage du réseau.

**Spécialités** :
- Cloudflare Tunnel
- Configuration réseau locale
- NFS (Network File System)
- Réseaux Docker
- Dépannage réseau

**Utilisation** :
```bash
vibe --prompt prompts/network-engineer.md
```

**Exemples de questions** :
- "Comment ajouter un nouveau service à Cloudflare Tunnel ?"
- "Pourquoi mon montage NFS échoue-t-il ?"
- "Comment configurer une IP statique pour un nouveau périphérique ?"
- "Mon Cloudflare Tunnel ne fonctionne plus, que faire ?"

---

### 5. `storage-admin` - Expert Stockage

**Fichier** : [`storage-admin.md`](storage-admin.md)

**Description** : Expert en gestion du stockage et des sauvegardes.

**Spécialités** :
- Gestion du NAS UGREEN
- Configuration NFS
- Stratégies de sauvegarde
- Stockage Docker
- Monitoring du stockage

**Utilisation** :
```bash
vibe --prompt prompts/storage-admin.md
```

**Exemples de questions** :
- "Comment créer un nouveau partage NFS ?"
- "Comment configurer des sauvegardes automatiques de mes conteneurs ?"
- "Comment restaurer un conteneur à partir d'une sauvegarde ?"
- "Comment monitorer l'espace disque de mon NAS ?"

---

### 6. `monitoring-specialist` - Expert Monitoring

**Fichier** : [`monitoring-specialist.md`](monitoring-specialist.md)

**Description** : Expert en surveillance, alerting et analyse des performances.

**Spécialités** :
- Surveillance des ressources
- Configuration des alertes
- Création de tableaux de bord
- Analyse des performances
- Journalisation centralisée

**Utilisation** :
```bash
vibe --prompt prompts/monitoring-specialist.md
```

**Exemples de questions** :
- "Comment déployer Prometheus + Grafana ?"
- "Comment centraliser tous mes logs Docker avec Loki ?"
- "Comment configurer des alertes par Telegram ?"
- "Crée-moi un tableau de bord Grafana pour Docker"

---

## 🚀 Comment Utiliser ces Prompts ?

### Avec Vibe CLI

1. **Créer un agent dédié** :
   ```bash
   # Créer un fichier de configuration pour un agent
   nano agents/homelab-expert.json
   ```
   
   Contenu :
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
       "Comment configurer une sauvegarde automatique vers le NAS ?"
     ]
   }
   ```

2. **Lancer l'agent** :
   ```bash
   vibe --agent homelab-expert
   ```

3. **Poser une question** :
   ```
   "Comment optimiser les performances de mon conteneur Nextcloud AIO ?"
   ```

### Sans Vibe CLI (Autres IA)

1. **Copier le contenu du prompt** :
   ```bash
   cat prompts/homelab-expert.md | pbcopy  # Mac
   cat prompts/homelab-expert.md | xclip -selection clipboard  # Linux
   ```

2. **Coller dans ton client IA** (ChatGPT, Claude, etc.)

3. **Poser ta question**

---

## 📊 Comparaison des Agents

| Agent | Spécialité | Niveau | Complexité | Cas d'usage |
|-------|------------|--------|------------|-------------|
| homelab-expert | Tout | Senior | ⭐⭐⭐⭐ | Questions générales, conseil architectural |
| docker-manager | Docker | Expert | ⭐⭐⭐ | Déploiement, optimisation, dépannage Docker |
| security-auditor | Sécurité | Expert | ⭐⭐⭐⭐ | Audit, durcissement, réponse aux incidents |
| network-engineer | Réseau | Senior | ⭐⭐⭐ | Cloudflare, NFS, réseau local |
| storage-admin | Stockage | Senior | ⭐⭐⭐ | NAS, sauvegardes, NFS |
| monitoring-specialist | Monitoring | Senior | ⭐⭐⭐⭐ | Prometheus, Grafana, alertes |

---

## 🎯 Quel Agent Choisir ?

### Pour des questions **générales** ou **multi-domaines** :
✅ Utilise **`homelab-expert`** (agent principal)

Exemples :
- "Comment améliorer mon infrastructure homelab ?"
- "Quelle est la meilleure façon de déployer [service X] ?"
- "Mon système a des problèmes, aide-moi à diagnostiquer"

---

### Pour des questions **spécifiques à Docker** :
✅ Utilise **`docker-manager`**

Exemples :
- "Crée-moi un docker-compose.yml pour [service]"
- "Mon conteneur [X] ne démarre pas"
- "Comment optimiser les performances de [conteneur] ?"
- "Quelles sont les bonnes pratiques pour sécuriser Docker ?"

---

### Pour des questions de **sécurité** :
✅ Utilise **`security-auditor`**

Exemples :
- "Fais un audit de sécurité de mon homelab"
- "Comment durcir la configuration SSH ?"
- "Comment configurer Fail2Ban ?"
- "Je pense avoir été hacké, que faire ?"

---

### Pour des questions **réseau** :
✅ Utilise **`network-engineer`**

Exemples :
- "Comment configurer Cloudflare Tunnel ?"
- "Pourquoi mon montage NFS échoue ?"
- "Comment configurer une IP statique ?"
- "Comment optimiser les performances réseau ?"

---

### Pour des questions de **stockage** ou **sauvegarde** :
✅ Utilise **`storage-admin`**

Exemples :
- "Comment créer un nouveau partage NFS ?"
- "Comment configurer des sauvegardes automatiques ?"
- "Comment restaurer depuis une sauvegarde ?"
- "Comment monitorer l'espace disque ?"

---

### Pour des questions de **monitoring** ou **alerting** :
✅ Utilise **`monitoring-specialist`**

Exemples :
- "Comment déployer Prometheus + Grafana ?"
- "Comment configurer des alertes ?"
- "Crée-moi un tableau de bord Grafana"
- "Comment centraliser mes logs ?"

---

## 🔧 Personnalisation des Prompts

### Ajouter des informations spécifiques

Tous les prompts sont **basés sur ton infrastructure** (UM880 Plus, NAS UGREEN, Cloudflare Tunnel, etc.).

Si tu modifies ton infrastructure :
1. Mets à jour les fichiers de configuration dans `configs/`
2. Mets à jour les prompts correspondants
3. Documente les changements dans `Documents/`

### Créer un nouvel agent spécialisé

Pour créer un nouvel agent :

1. **Créer le fichier de prompt** :
   ```bash
   nano prompts/mon-nouvel-agent.md
   ```

2. **Suivre la structure standard** :
   ```markdown
   # Nom de l'Agent - Agent Spécialisé
   > Description
   
   ---
   
   ## 🎯 IDENTITÉ ET RÔLE
   **Tu es** : [Description du rôle]
   **Ta mission** : [Mission]
   
   ---
   
   ## 📋 CONTEXTE TECHNIQUE
   [Détails spécifiques à ton infrastructure]
   
   ---
   
   ## 🎯 RÔLES ET RESPONSABILITÉS
   [Liste des tâches]
   
   ---
   
   ## ⚠️ RÈGLES CRITIQUES
   [Règles de sécurité]
   
   ---
   
   ## 📝 FORMAT DES RÉPONSES
   [Structure attendue]
   
   ---
   
   ## 🚀 EXEMPLES DE TÂCHES COURANTES
   [Exemples concrets]
   
   ---
   
   ## 🎯 PREMIÈRE INTERACTION
   [Message d'accueil]
   ```

3. **Ajouter l'agent à AGENTS.md** :
   ```markdown
   ### `mon-nouvel-agent`
   **Description** : [Description]
   **Prompt** : `prompts/mon-nouvel-agent.md`
   **Spécialisé dans** : [Liste des spécialités]
   ```

---

## 📚 Bonnes Pratiques

### 1. Toujours vérifier les réponses
- Même si l'agent est bien configuré, **vérifie toujours** les commandes avant de les exécuter
- **Teste en environnement isolé** quand c'est possible

### 2. Documenter les changements
- Si l'agent te propose une modification, **documente-la** dans `Documents/`
- Note les changements dans un **changelog**

### 3. Maintenir les prompts à jour
- Mets à jour les prompts quand ton infrastructure change
- Ajoute de nouveaux **exemples concrets** au fur et à mesure

### 4. Combiner les agents
- Pour des problèmes complexes, **utilise plusieurs agents** :
  - `network-engineer` pour le diagnostic réseau
  - `docker-manager` pour les problèmes Docker
  - `security-auditor` pour vérifier la sécurité

---

## 🔍 Dépannage

### L'agent ne comprend pas ma question
- **Sois plus précis** : Donne plus de contexte
- **Utilise un agent plus spécialisé** : Si ta question est très spécifique
- **Réformule ta question** : Essaie avec des mots-clés différents

### L'agent propose des solutions inadaptées
- **Vérifie le contexte technique** dans le prompt
- **Corrige les informations** si elles ne correspondent plus à ta réalité
- **Utilise un prompt plus général** (homelab-expert)

### L'agent propose des commandes dangereuses
- **Ne jamais exécuter** une commande destructrice sans confirmation
- **Demande une explication** : "Pourquoi cette commande ?"
- **Vérifie avec la documentation** officielle

---

## 📖 Documentation Complémentaire

- [Vibe CLI Documentation](https://github.com/mistralai/vibe)
- [Prompt Engineering Guide](https://github.com/dair-ai/Prompt-Engineering-Guide)
- [Homelab Documentation](Documents/homelab-documentation-technique.md)
- [Cloudflare Tunnel Docs](https://developers.cloudflare.com/cloudflare-one/connections/connect-apps/)
- [Docker Documentation](https://docs.docker.com/)

---

## 🎓 Ressources Externes

### Communautés
- [r/homelab](https://www.reddit.com/r/homelab/) - Communauté active
- [r/selfhosted](https://www.reddit.com/r/selfhosted/) - Services auto-hébergés
- [TRaSH Guides](https://trash-guides.info/) - Guides détaillés

### Outils Recommandés
- [Portainer](https://www.portainer.io/) - Gestion Docker
- [Watchtower](https://containrrr.dev/watchtower/) - Mises à jour automatiques
- [Netdata](https://www.netdata.cloud/) - Monitoring temps réel
- [Grafana](https://grafana.com/) - Visualisation
- [Prometheus](https://prometheus.io/) - Collecte de métriques

---

## 📝 Historique des Modifications

| Date | Agent | Modification | Auteur |
|------|-------|--------------|--------|
| 2026-06-24 | Tous | Création initiale | Stéphane |
| 2026-06-24 | homelab-expert | Prompt principal créé | Stéphane |
| 2026-06-24 | docker-manager | Prompt Docker spécialisé | Stéphane |
| 2026-06-24 | security-auditor | Prompt sécurité spécialisé | Stéphane |
| 2026-06-24 | network-engineer | Prompt réseau spécialisé | Stéphane |
| 2026-06-24 | storage-admin | Prompt stockage spécialisé | Stéphane |
| 2026-06-24 | monitoring-specialist | Prompt monitoring spécialisé | Stéphane |

---

## 💡 Conseils pour des Réponses Optimales

1. **Sois précis** : Plus ta question est détaillée, meilleure sera la réponse
2. **Fournis du contexte** : Décris ton infrastructure, tes objectifs, tes contraintes
3. **Montre ce que tu as déjà essayé** : Évite que l'agent te propose des solutions que tu as déjà testées
4. **Demande des explications** : "Pourquoi cette solution ?", "Quels sont les risques ?"
5. **Documente** : Note les solutions qui fonctionnent pour référence future

---

**Prêt à utiliser les agents ?** 🚀

Choisis un agent et pose-lui ta première question !
