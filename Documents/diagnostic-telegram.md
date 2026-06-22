---
date: 2026-05-15
type: doc
tags: [homelab, telegram, monitoring, cron]
status: active
project: homelab
---

# Diagnostic homelab via Telegram

> Rapport automatique poussé deux fois par jour sur `@anthemion_assistant_bot` (chat_id 8648148098). Consolidation du 2026-05-15 — remplace l'ancien `homelab-morning.sh` qui poussait sur `@anthemion_homelab_bot` (token révoqué).

## Vue d'ensemble

- **Script** : `/home/steph/bin/homelab-diagnostic.sh` (~226 lignes Bash)
- **Config (token + chat_id)** : `/home/steph/.config/homelab-diagnostic/env` (chmod 600)
- **Cron** : user `steph` sur UM880, à **07:00** et **20:00**
- **Bot Telegram** : `@anthemion_assistant_bot` (claude-bot service, plugin officiel)
- **Logs** : `/home/steph/.config/homelab-diagnostic/log`
- **Ancien script** : `/usr/local/bin/homelab-morning.sh.disabled` (renommé, à supprimer plus tard)
- **Ancien token** : `/home/steph/.openclaw/secrets/telegram-homelab-bot.token.revoked-2026-05-15` (révoqué côté BotFather le 15/05)

## Périmètre couvert

### Système UM880
- Uptime, load average, RAM utilisée/totale, disque `/` utilisé/total/%
- Seuil disque : alerte si > 85 %

### Températures UM880 (6 sondes)
- CPU AMD Ryzen (k10temp Tctl)
- NVMe Kingston OM8TAP41024K1 : Composite + max sensor
- GPU AMD (amdgpu edge)
- RAM (SPD)
- Ethernet (chipset r8169)
- Seuils : CPU/GPU > 80 °C ou NVMe max > 70 °C = dégradé

### Services
- Containers Docker critiques (LADTC app+db, Nextcloud, Collabora, Coolify)
- Systemd : `claude-bot.service`, `syncthing@claude-bot.service`
- Toute absence d'un container ou service inactif → dégradé

### UPS Eaton (via `upsc eaton@localhost`)
- Status (`OL` attendu), charge batterie, voltage entrée
- Seuils : status ≠ `OL` ou charge < 95 % = dégradé

### Sauvegarde B2 (rclone vers Backblaze)
- Lit le dernier `B2 backup complete` dans `/var/log/rclone-b2-backup.log`
- Calcule l'âge en heures
- Seuils : pas de log de complétion ou âge > 36 h = dégradé

### fail2ban SSH
- Nombre de bans actifs sur le jail `sshd` (via `sudo -n fail2ban-client status sshd`)
- Seuil : > 20 bans = dégradé (signal d'attaque distribuée)

### URLs publiques Cloudflare
- Test HTTP de `https://coolify.anthemion.dev`, `https://uptime.anthemion.dev`, `https://cloud.anthemion.dev`
- Code HTTP + latence
- Tout code ≠ 200/301/302/401 = dégradé

### NAS Ugreen (192.168.129.21)
- SSH vers `Steph@192.168.129.21` (clé déployée homelab→NAS, smartctl NOPASSWD configuré)
- Uptime, disk usage `/volume1`
- Températures des 3 disques (sda USB NVMe, sdb+sdc HDD ST4000VN006)
- NAS unreachable → dégradé

## Verdict global

Le titre du message commence par :
- **`homelab OK — YYYY-MM-DD HH:MM`** si tous les seuils OK
- **`homelab DÉGRADÉ — YYYY-MM-DD HH:MM`** si un seul seuil enfreint (l'utilisateur scrolle pour identifier)

## Format de notification (mise à jour 2026-05-15)

Le script applique une logique **brief/détail** :

- **Si verdict = OK** → message bref : `homelab OK — YYYY-MM-DD HH:MM ↳ envoyer diag au bot pour le détail`
- **Si verdict = DÉGRADÉ** → rapport complet envoyé immédiatement

Le rapport complet est **toujours** sauvegardé dans `/var/log/homelab-diagnostic/latest.md` (chmod 644, lisible par `claude-bot` via groupe `adm`).

Message Telegram en HTML, `disable_notification=true` (n'allume pas l'écran du Pixel).

### Magic word `diag` côté claude-bot

Le fichier `/home/claude-bot/CLAUDE.md` contient une instruction explicite : quand l'utilisateur envoie `diag` (ou variantes `diagnostic`, `status`, `état`) au bot `@anthemion_assistant_bot`, Claude :

1. Lit `/var/log/homelab-diagnostic/latest.md` via Bash tool
2. Renvoie son contenu tel quel (déjà au format HTML Telegram)
3. Si le fichier n'existe pas, répond que le diagnostic n'a pas encore tourné

Si Claude ne pige pas le magic word à coup sûr, l'instruction peut être renforcée dans `/home/claude-bot/CLAUDE.md` ou transformée en skill custom dans `~/.claude/skills/homelab-diag/SKILL.md`.

## Architecture monitoring finale (2026-05-15)

Deux couches complémentaires, **un seul bot Telegram** (`@anthemion_assistant_bot`) :

### Couche 1 — Cron diagnostic (`homelab-diagnostic.sh`)

- **Rapport structuré** 2× par jour (07:00 + 20:00)
- Verdict global OK / DÉGRADÉ avec seuils détaillés (cf. plus bas)
- Mode adaptatif : brief si OK, complet si DÉGRADÉ
- À la demande via magic word `diag`
- Couvre des indicateurs **non métriques** que Beszel ne suit pas : UPS Eaton, sauvegarde B2, fail2ban SSH, URLs publiques, températures NAS distantes

### Couche 2 — Beszel temps réel

- Container `beszel` sur UM880, dashboard http://192.168.129.10:8090
- Agent `beszel-agent` collecte CPU, RAM, disk, GPU, températures, network, Docker containers en continu (~30s)
- Alertes configurées sur le système `um880` :
  - System Down (10 min)
  - CPU usage > 80 % (5 min)
  - Memory usage > 90 % (5 min)
  - Disk usage > 85 % (10 min)
  - **Temperature > 80 °C (10 min)** — sensor max parmi toutes les sondes UM880
- Notifier configuré : Shoutrrr Telegram URL avec le même bot et chat_id que le cron
- Couvre tout ce qui est métrique système temps réel

### Répartition

| Indicateur | Cron diag | Beszel |
|---|---|---|
| CPU usage | ✗ | ✓ |
| Memory usage | basique | ✓ détaillé |
| Disk usage | ✓ verdict | ✓ alerte |
| Températures UM880 | ✓ sensor-par-sensor + seuils granulaires | ✓ alerte globale max |
| Températures NAS distantes | ✓ (via SSH smartctl) | ✗ |
| UPS Eaton | ✓ | ✗ |
| Sauvegarde B2 | ✓ age | ✗ |
| fail2ban bans | ✓ | ✗ |
| URLs publiques Cloudflare | ✓ HTTP code + latence | ✗ |
| Container Docker status | ✓ critiques nommés | ✓ tous |
| System down | ✓ via NAS unreachable | ✓ via heartbeat |

Beszel = monitoring continu, alerte temps réel.
Cron diag = inventaire périodique + indicateurs non métriques + on-demand.

## Modifier le script ou les seuils

```bash
ssh homelab
vim /home/steph/bin/homelab-diagnostic.sh
# Test manuel
/home/steph/bin/homelab-diagnostic.sh
# Le message arrive immédiatement sur Telegram, vérifier
```

## Pannes possibles et debug

| Symptôme | Cause probable | Fix |
|---|---|---|
| Pas de message reçu à 7h ou 20h | Cron user steph ne tourne pas | `crontab -l` et `systemctl status cron` |
| `Telegram FAILED` dans le log | Token révoqué ou wrong | Régénérer côté BotFather, mettre à jour `env` |
| NAS unreachable | Clé SSH expirée ou NAS éteint | `ssh Steph@192.168.129.21 hostname` |
| Températures = n/a | Hwmon a changé d'index après reboot | Re-mapper `/sys/class/hwmon/hwmon*` |

## Rotation du token

Si le token Telegram fuit (ex. dans un commit ou un log) :
1. `@BotFather` → `/mybots` → `@anthemion_assistant_bot` → API Token → **Revoke**
2. Récupérer le nouveau token
3. `ssh homelab` puis modifier `/home/steph/.config/homelab-diagnostic/env` avec le nouveau
4. Mettre à jour aussi `/home/claude-bot/.claude/channels/telegram/.env` (claude-bot service utilise le même bot)
5. `sudo systemctl restart claude-bot` pour reprendre les commandes claude depuis Telegram
6. Tester manuellement le script

## Évolutions possibles

- Ajouter des **alertes silencieuses** ou bruyantes selon le verdict (changer `disable_notification` selon DÉGRADÉ vs OK)
- Pousser uniquement en cas de dégradé (silence quand tout va bien) — réduire le bruit
- Étendre vers d'autres targets : Vercel deployments, GitHub Actions, certs Cloudflare expiration
- Beszel couvre déjà les métriques système temps réel — ce script reste utile pour les indicateurs **non métriques** (UPS, B2, fail2ban, températures disques NAS)
