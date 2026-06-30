# UM880 scripts

Scripts that live on the UM880 host (`192.168.129.10`, `ssh homelab`), versioned here as a mirror. They are **not** deployed from this repo — edit on the host, then re-sync here.

## `homelab-diagnostic.sh`

- **Runtime path on host**: `/home/steph/bin/homelab-diagnostic.sh`
- **Config (token + chat_id)**: `/home/steph/.config/homelab-diagnostic/env` (chmod 600, not in repo)
- **Cron**: user `steph`, 07:00 and 20:00
- **Output**: pushes status to Telegram `@anthemion_assistant_bot`; full report saved to `/var/log/homelab-diagnostic/latest.md`
- **Verdict**: title starts with `homelab OK` or `homelab DÉGRADÉ` if any threshold is breached.

Covers UM880 (system, temps), services (Docker + systemd), UPS Eaton, B2 backup age,
fail2ban, public Cloudflare URLs, and the NAS Ugreen (via SSH + smartctl).

See `Documents/diagnostic-telegram.md` for the full design.

### Re-sync after editing on the host

```bash
ssh homelab 'cat /home/steph/bin/homelab-diagnostic.sh' > scripts/um880/homelab-diagnostic.sh
```

### Known gotcha — NAS "unreachable"

If the NAS shows `unreachable` (uptime/temps `n/a`) but pings fine and port 22 is open,
the UGOS firmware update wiped the UM880 SSH key from the NAS `authorized_keys`.
Reinstall the UM880 pubkey (`~/.ssh/id_ed25519.pub`) into `Steph@192.168.129.21:~/.ssh/authorized_keys`
and `chmod 700 ~ ~/.ssh` on the NAS. Not a hardware failure.
