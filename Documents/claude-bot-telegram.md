---
date: 2026-05-10
tags: [homelab, claude-code, telegram, bot]
status: actif
---

# Bot Claude Code Telegram

Service homelab : un agent Claude Code distant accessible par DM Telegram. Permet d'interroger Claude depuis le mobile, avec accès aux MCPs configurés (Google Calendar, et plus à venir).

## Architecture

- **Hôte** : UM880 ([[reference_homelab_hardware|192.168.129.10]])
- **User dédié** : `claude-bot` — isolé du user `steph`, non-sudo
- **Supervision** : service systemd `claude-bot.service` (Restart=always, enabled au boot)
- **Allocation TTY** : `script -qec ... /dev/null` — fournit le pty exigé par le REPL Claude Code
- **Channel** : plugin officiel `claude-plugins-official/telegram@0.0.6`
- **MCP server** : subprocess Bun, polling Telegram API en continu
- **Modèle** : Sonnet (configurable dans `settings.json`)
- **Permissions** : `--dangerously-skip-permissions` + `skipDangerousModePermissionPrompt: true` + `hasTrustDialogAccepted: true` (dans `~/.claude.json` projects entry)

## Sécurité

- Allowlist verrouillée : seul l'user Telegram ID `8648148098` peut atteindre le bot
- Pairings désactivés — aucun nouvel utilisateur ne peut se connecter
- `permissions.deny` dans `settings.json` bloque les commandes destructrices critiques (`mkfs*`, `dd if=* of=/dev/sd*`, `chown -R root*`)
- User `claude-bot` sans privilèges sudo

## Fichiers clés

| Path | Contenu |
|------|---------|
| `/home/claude-bot/.claude/settings.json` | Config Claude (modèle, permissions, plugin actif) |
| `/home/claude-bot/.claude/channels/telegram/.env` | Token bot Telegram |
| `/home/claude-bot/.claude/channels/telegram/access.json` | Allowlist (IDs autorisés) |
| `/home/claude-bot/.claude/channels/telegram/bot.pid` | PID du subprocess Bun |
| `/home/claude-bot/.credentials.json` | Auth Anthropic |

## Service systemd

Unit : `/etc/systemd/system/claude-bot.service`.

```ini
[Unit]
Description=Claude Code Telegram bot
After=network-online.target
Wants=network-online.target
StartLimitIntervalSec=300
StartLimitBurst=5

[Service]
Type=simple
User=claude-bot
Group=claude-bot
WorkingDirectory=/home/claude-bot
ExecStart=/usr/bin/script -qec "/home/claude-bot/start-bot.sh" /dev/null
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
```

Wrapper `/home/claude-bot/start-bot.sh` (mode 750, owner `claude-bot`) :

```bash
#!/bin/bash -l
exec /home/claude-bot/.local/bin/claude \
  --channels plugin:telegram@claude-plugins-official \
  --dangerously-skip-permissions
```

Le `-l` (login shell) charge `PATH` complet pour rendre `bun` accessible. Le `script -qec ... /dev/null` alloue un pty (sans lui, le REPL Claude bascule en mode `--print` non-interactif et crash avec `Input must be provided either through stdin or as a prompt argument`).

## Commandes courantes

```bash
# État
ssh homelab 'sudo systemctl status claude-bot'

# Logs
ssh homelab 'sudo journalctl -u claude-bot -f'

# Restart
ssh homelab 'sudo systemctl restart claude-bot'

# Process tree (vérification rapide)
ssh homelab 'ps -ef | grep -E "script.*start-bot|claude --|bun.*telegram" | grep -v grep'
```

Indicateurs sains :
- `systemctl status claude-bot` : `active (running)`
- 3 processus actifs : `script` (parent), `claude --channels ...`, `bun run ... telegram` (subprocess MCP)
- MCP log récent dans `~/.cache/claude-cli-nodejs/-home-claude-bot/mcp-logs-plugin-telegram-telegram/` mentionne "Channel notifications registered"

## Pièges rencontrés au déploiement (10/05/2026)

1. **Trust dialog** au premier lancement — envoyer `Enter` pour valider "Yes, I trust this folder". Alternative durable : forcer `projects."/home/claude-bot".hasTrustDialogAccepted: true` dans `~/.claude.json` (sinon le service crash au reboot avec un nouveau pty)
2. **Bypass permissions dialog** — `skipDangerousModePermissionPrompt: true` dans `settings.json` skippe la confirmation
3. **PATH tronqué** — `sudo -u claude-bot env XDG_RUNTIME_DIR=...` casse `bun`. Toujours utiliser un login shell (`-i` ou shebang `#!/bin/bash -l`)
4. **TTY exigé** — sans pty, claude détecte stdin/stdout non-interactifs et bascule en `--print` (qui exige un prompt → crash). Sous systemd : encapsuler dans `script -qec`. Sous tmux : pty fourni nativement
5. **Queue de messages** — premier DM consommé trop tôt si le polling démarre avant que le REPL soit prêt. Tester avec un second DM après confirmation visuelle
6. **`StartLimitIntervalSec`** doit aller dans `[Unit]`, pas `[Service]` (sinon `systemd-analyze verify` warn et le rate-limit ne s'applique pas)

## Maintenance

- **Mise à jour Claude Code** : `sudo -u claude-bot -i bash -c "claude update"` puis `sudo systemctl restart claude-bot`
- **Logs MCP plugin** : `~/.cache/claude-cli-nodejs/-home-claude-bot/mcp-logs-plugin-telegram-telegram/*.jsonl`
- **Logs service** : `journalctl -u claude-bot` (les blob ANSI/TUI du REPL sont filtrés par journald comme `[NB blob data]`, c'est normal)

## TODO

- [x] Service systemd `claude-bot.service` pour redémarrage automatique au boot ✓ 2026-05-10
- [ ] Monitoring : alerte si le service tombe (probe `systemctl is-active claude-bot` à intégrer dans `homelab-morning.sh` ou checks Beszel)
- [ ] Tester DMs avec actions système (uptime, disk usage) pour cadrer le scope opérationnel
- [ ] Ajouter MCPs utiles : Gmail, Vercel selon usage réel

## Références

- Plugin officiel : `claude-plugins-official/telegram@0.0.6`
- Bot Telegram : `@anthemion_assistant_bot` (display name « Anthemion Assistant »). Le username `@anthemion_homelab_bot` a été utilisé jusqu'au 14/05, depuis le service est sur `@anthemion_assistant_bot`. L'ancien `@anthemion_homelab_bot` est un bot diagnostic séparé (hôte inconnu, à révoquer).
- Allowlist user ID : 8648148098
- Voir aussi : [[reference_homelab_hardware]], [[monitoring-homelab]]
