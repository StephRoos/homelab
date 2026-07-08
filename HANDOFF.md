# HANDOFF — homelab

> Last updated: 2026-07-07. Written for a fresh AI agent (or future Stéphane) resuming work
> with zero prior context. For the in-flight Google-exit migration, the authoritative,
> self-contained status doc is [`Documents/google-exit-status-handoff-2026-07-07.md`](Documents/google-exit-status-handoff-2026-07-07.md)
> — read it first if the task touches Photos/Mail/Drive/backup. This file covers the repo itself.

## 1. What this is

Version-controlled **brain of the physical homelab** — not an application. It holds:

- **Mirrored operational scripts** that actually run on the UM880 server (`scripts/um880/`)
- **Reference Docker/system configs** for the services hosted there (`configs/`)
- **Operational documentation**: architecture, audits, incident post-mortems, migration plans (`Documents/`)
- **AI agent prompts** for homelab administration via Vibe CLI (`AGENTS.md`, `prompts/`, `agents/`)

The homelab hosts Stéphane's personal degoogled cloud (Immich, Nextcloud) and the deployment
platform (Coolify) used by his other projects (hillsrun.com, ladtc.be, anthemion.dev, portfolio).
It is the infrastructure layer under the whole Anthemion / personal-projects ecosystem.

## 2. Current state (2026-07-07)

- **Maturity: production infra.** The homelab itself runs 24/7 and serves live sites
  (including `ladtc.be` with Stripe checkout). The repo is a mirror/documentation of it.
- **Git: clean** apart from this `HANDOFF.md` itself (untracked, not yet committed), `main` up to
  date with remote `https://github.com/StephRoos/homelab.git` (private).
  Last commits (2026-07-07): `15db350`/`18656f4`/`1faece6` (Google-exit handoff doc) and
  `3df9148` (Immich coverage in the B2 backup).
- **In flight — Google exit** (see the dedicated handoff doc, §6 for the ordered list):
  1. [blocking] Verify the first full Immich → B2 backup finished (~84 GB in `b2:homelab-backup-anthemion/immich-library`)
  2. Human visual spot-check of Immich years 2008/2016
  3. Then, and only then, the destructive steps (disable Pixel Google Photos backup, later delete the Google Photos library)
  - Mobile calendar/contacts sync: **deliberately parked** (DAVx5 rejected by Stéphane — do not re-propose unsolicited).
- **Known half-done / stale in the repo:**
  - `Documents/` contains **superseded generations of guides** (`homelab-guide.md`, `-final`, `-post-audit`, `-audit-2026-06-23`, `homelab-manuel.md`…). Several are archived in SecondBrain `04-Archives/homelab/` — the live architecture truth is SecondBrain `02-Areas/homelab/architecture-homelab.md`, not these files.
  - `Documents/migration-cloudflare-to-caddy.md` is **explicitly flagged partially abandoned** (header warning, 2026-06-28) — kept for history.
  - `configs/docker/README.md` describes Caddy on the NAS routing `git.stephaneroos.com`, Dashy, etc. — **partly outdated** vs the real 2026-06-29 architecture (single Cloudflare tunnel, Caddy HTTP-only for `stephaneroos.com` subdomains).
  - `configs/docker/immich-official.yml` is an **empty file** (0 bytes) — dead artifact.
  - `configs/network/` is an **empty directory**.
  - `scripts/README.md` documents scripts that do not exist in the repo (`deploy-immich.sh`, `backup-immich.sh`, `restore-immich.sh`, `migrate-immich-photos.sh`) — drifted.
  - `AGENTS.md` / `prompts/` / `agents/homelab-expert.json` were built for **Vibe CLI** (2026-06-24); mostly unused since Claude Code took over the ops sessions.

## 3. Architecture & stack

**Physical infra (what the repo describes):**

| Element | Value |
|---|---|
| Server | Minisforum UM880 Plus — Ubuntu 24.04, Ryzen 7 8845HS, 32 GB RAM, 1 TB NVMe — `192.168.129.10`, SSH alias `homelab` (user `steph`) |
| NAS | UGREEN (UGOS, ARM64, 2×4 TB RAID1) — `192.168.129.21`, SSH user `Steph`, exports NFS |
| NFS mounts on UM880 | `/mnt/nas/{nextcloud,appdata,backups,timemachine,nextcloud-personal}` |
| Immich library | `/mnt/nas/immich` — **local UM880 disk despite the path name**, ~111 GB |
| Ingress | **Cloudflare Tunnel only** (no port forwarding on the box); Caddy HTTP-only behind it for `stephaneroos.com` subdomains |
| Platform | Docker (~26 containers) + Coolify (deploys hillsrun.com :3001, portfolio, uptime…) |
| Offsite backup | Backblaze B2 bucket `homelab-backup-anthemion`, rclone, cron `/etc/cron.d/b2-backup` daily 04:00 |
| Monitoring | `homelab-diagnostic.sh` cron 07:00/20:00 → Telegram `@anthemion_assistant_bot`; Uptime Kuma |
| Resilience | UPS Eaton Ellipse PRO 1600 via NUT; UFW + Fail2Ban |

**Repo layout (all paths relative to `/Users/stephane/Projects/homelab/`):**

```
AGENTS.md                  # AI agent roster for homelab admin (Vibe CLI era, mostly historical)
prompts/*.md               # per-role admin prompts (homelab-expert, docker-manager, security-auditor…)
agents/homelab-expert.json # Vibe CLI agent config
configs/docker/            # reference compose files: immich.yml, nextcloud-personal.yml (+.env.example),
                           # nextcloud-aio.yml, coolify.yml, uptime-kuma.yml, caddy.yml + Caddyfile,
                           # cloudflared-immich.yml, nginx-immich-{api,internal}.conf, daemon.json,
                           # README.md (partly outdated, see §2) + README-networks.md
configs/system/            # netplan.yaml, ufw-rules.txt, fail2ban-jail.local, cloudflared-immich.service, README.md
scripts/um880/             # LIVE scripts, mirrored from the host (see §4 sync rule) + README.md
  homelab-diagnostic.sh    #   twice-daily health report → Telegram (253 lines)
  b2-backup.sh             #   nightly pg dumps + rclone sync to B2, incl. Immich originals (46 lines)
                           #   (not yet described in scripts/um880/README.md — added 2026-07-07)
scripts/*.sh               # older utility scripts (backup/restore/update/import…), largely superseded
Documents/                 # 22 md docs: architecture, audits, incidents, plans (see §2 for which are live)
```

**Key live documents:**
- `Documents/google-exit-status-handoff-2026-07-07.md` — migration state, ordered next steps, traps
- `Documents/incident-redirect-loop-2026-06-28.md` — post-mortem of the 308-loop outage (explains the current routing rules)
- `Documents/diagnostic-telegram.md` — design of the monitoring script
- `Documents/homelab-cloudflare-coolify-architecture.md` — tunnel/Coolify routing reference

## 4. How to run

There is **no build, no tests, no CI** — this is an infra/docs repo. Operations happen over SSH.

```bash
ssh homelab                    # UM880 (user steph, 192.168.129.10)
ssh Steph@192.168.129.21       # NAS UGREEN
```

The `homelab` alias lives in the local `~/.ssh/config` of Stéphane's machines (key-based auth).
If the alias is missing (new machine/agent), fall back to `ssh steph@192.168.129.10` — but you
still need the private key; there is no password auth path documented in this repo.

**Critical convention — script mirroring:** files in `scripts/um880/` live on the host at
`/home/steph/bin/` and are **edited on the host first**, then re-synced into the repo:

```bash
ssh homelab 'cat /home/steph/bin/homelab-diagnostic.sh' > scripts/um880/homelab-diagnostic.sh
```

Nothing is deployed *from* this repo automatically. Pushing to GitHub does not change the server.

**Routine checks:**

```bash
ssh homelab 'sudo tail -5 /var/log/rclone-b2-backup.log'                    # nightly B2 backup status
ssh homelab 'sudo rclone size b2:homelab-backup-anthemion/immich-library'   # Immich offsite size (~84 GiB expected)
ssh homelab 'cat /var/log/homelab-diagnostic/latest.md'                     # last full health report
```

Compose files under `configs/docker/` are **references**; the running copies live on the
UM880 (and Caddy on the NAS at `/home/Steph/caddy/`). Apply changes on the host, then update
the repo copy.

## 5. Dependencies & credentials

Env var NAMES / secret locations only (never values; `.env` files are gitignored):

- `configs/docker/nextcloud-personal.env.example` → `NEXTCLOUD_DB_PASSWORD`, `NEXTCLOUD_REDIS_PASSWORD`, `NEXTCLOUD_ADMIN_USER`, `NEXTCLOUD_ADMIN_PASSWORD`
- On the UM880 host (not in repo):
  - `/home/steph/.config/homelab-diagnostic/env` — Telegram bot token + chat_id (chmod 600)
  - `/home/steph/.secrets/postgres-shared.pass` — shared Postgres password used by `b2-backup.sh`
  - rclone remote `b2:` config (root) — Backblaze B2 keys
  - Immich API key: managed in the Immich UI (profile → API Keys). **Never store it in `/tmp`** (lost on reboot — already happened).
- External services: Cloudflare (DNS + Tunnel for `stephaneroos.com` and `anthemion.dev`), Backblaze B2, Infomaniak (personal mail `steph@stephaneroos.com`), OVH (pro mail `anthemion.dev` — do not touch yet), GitHub (this repo), Telegram (alerts).

## 6. Open work (ordered)

1. **Google exit — finish §6 of the migration handoff** (verify Immich B2 backup → visual spot-check → only then the destructive Google Photos steps). This is the only time-sensitive work.
2. **Repo hygiene** (low effort, high clarity):
   - Delete or archive superseded docs in `Documents/` (keep one architecture doc + incidents + live plans; point to SecondBrain for the rest)
   - Fix `scripts/README.md` (documents scripts that don't exist) and `configs/docker/README.md` (pre-2026-06-28 routing)
   - Document `b2-backup.sh` in `scripts/um880/README.md` (currently only covers the diagnostic script)
   - Commit this `HANDOFF.md` (currently untracked)
   - Remove `configs/docker/immich-official.yml` (empty) and the empty `configs/network/`
   - Add a root `README.md` (this HANDOFF can seed it)
3. **Decide the fate of the Vibe agent layer** (`AGENTS.md`, `prompts/`, `agents/`): either wire it into Claude Code (e.g. as skills/subagents) or archive it.
4. Backlog ideas from `Documents/plan-deconstruire-google.md`: unified portal (Dashy at `home.stephaneroos.com`), later mail migration `anthemion.dev` OVH → Infomaniak.

## 7. Pitfalls & gotchas

(Condensed; full list in the migration handoff §7.)

- **The repo is a mirror, not a deployment source.** Editing `scripts/um880/*` here does nothing until copied to the host. Always check host state first.
- **NAS "unreachable" in the diagnostic ≠ hardware failure**: UGOS firmware updates wipe the UM880's pubkey from the NAS `authorized_keys`. Reinstall the key + `chmod 700 ~ ~/.ssh` on the NAS.
- **No port forwarding on the box** — hairpin NAT makes LAN-side tests lie. All public ingress is the Cloudflare Tunnel; Caddy cannot do Let's Encrypt (hence `auto_https off`). This killed the Caddy-only migration plan.
- **Two Nextclouds**: `cloud.stephaneroos.com` = personal non-AIO stack (`nextcloud-personal`, host :11002); `cloud.anthemion.dev` = separate AIO instance (pro). Do not confuse them.
- **Immich DB**: container `immich-postgres`, table `asset` (singular), user `immich`, trust auth. For counts filter `deletedAt IS NULL`.
- **macOS NFD filenames** are rejected by Nextcloud — normalize to NFC before `occ files:scan`; `chown 33:33` for www-data.
- **macOS rsync is 2.6.9** — use `tar | ssh` pipelines for transfers with accents/spaces.
- Many `Documents/*.md` are **historical, not current** — trust file dates, header warnings, and SecondBrain `02-Areas/homelab/architecture-homelab.md` over older guides.

## 8. Pointers

- **SecondBrain (source of truth for docs):**
  - `~/SecondBrain/02-Areas/homelab/architecture-homelab.md` — living architecture reference (+ `.html` visual)
  - `~/SecondBrain/02-Areas/homelab/google-exit-plan.md`, `gap-analysis-google-photos-immich.md`, `setup-immich-mobile-autoupload.md`
  - `~/SecondBrain/04-Archives/homelab/` — archived old guides (mirrors of the stale `Documents/` files)
  - Daily notes with session logs: `~/SecondBrain/Daily/2026-06-28.md`, `2026-06-29.md`, `2026-07-01.md`, `2026-07-07.md`
- **Claude auto-memory** (in `~/.claude/projects/-Users-stephane-Projects/memory/`): `project_homelab.md`, `reference_homelab_hardware.md`, `reference_homelab_morning_script.md`, `reference_homelab_claude_bot.md`, `reference_um880_cloudflare_tunnel.md`, `reference_coolify_diagnostic.md`, `feedback_homelab_one_project.md`
- **Related projects**: HillsRun (deployed on Coolify here), my-portfolio, ladtc (production site behind the same tunnel), `hills-run-telegram-watch.sh` (sibling script in `~/Projects`)
- **Remote**: `https://github.com/StephRoos/homelab.git` (branch `main`)
