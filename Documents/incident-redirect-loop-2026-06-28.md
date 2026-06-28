# Incident: Infinite 308 redirect loop — ladtc.be + 5 domains

**Date:** 2026-06-28
**Severity:** High (ladtc.be = production site with Stripe checkout, fully down)
**Duration:** outage pre-existing; resolved same session
**Status:** Resolved — 6 domains back online

---

## TL;DR

`ladtc.be` was down with an infinite `308 Permanent Redirect` loop to itself.
Root cause: the Cloudflare Tunnel routed the public domains to **Caddy**
(`localhost:80`), but Caddy had no site block for those domains — so Caddy
returned its automatic HTTP→HTTPS redirect on traffic that arrived **already
decrypted** from the tunnel, looping forever.

Same root cause affected 6 domains. All fixed by making the tunnel point
**directly** to each container (published host port or Docker IP), and for the
personal domain by serving Caddy in HTTP-only behind the tunnel.

---

## Architecture context (what's on the NAS)

```
Internet → Cloudflare (proxy) → cloudflared tunnel (host process, PID on NAS)
                                 → Caddy (host network, :80/:443)
                                 → containers (LADTC, Forgejo, Immich, Coolify...)
```

- **Tunnel** `6b5cb58d-2344-4653-8d0b-ba7723f8ac6d` is *remotely-managed*
  (config lives in the Cloudflare dashboard, not on disk).
- **Caddy** is the internal reverse proxy (host network). Caddyfile at
  `configs/docker/Caddyfile`, mounted from the repo clone at
  `/home/steph/homelab/configs/docker/Caddyfile`.
- **coolify-proxy** (Traefik, Coolify's own proxy) was **down for 2 days**
  (mid-migration to Caddy), so Coolify apps were no longer routed by Traefik.

> NAS SSH: `ssh homelab` → `192.168.129.10` (NOT `.21` — the `.21` in some docs
> is stale). Public IP `91.182.179.8`, but **no port forwarding 80/443** on the
> box (hairpin NAT only), so Caddy-direct + Let's Encrypt cannot work — TLS must
> come from the Cloudflare edge.

---

## Symptoms

```
$ curl -sIL https://ladtc.be/
HTTP/2 308
location: https://ladtc.be/
HTTP/2 308
location: https://ladtc.be/   ... infinite loop
```

- Cloudflare responded in ~90 ms, body empty, `server: cloudflare`.
- **Every path** looped to itself (`/`, `/api/health`, `/contact`...).
- The tunnel was **up** (cloudflared systemd active) and the app was **healthy**
  (`HTTP 200` on the container IP). So this was *not* a tunnel outage or app
  crash — it was a **routing/redirect** problem.

---

## Root cause

Two layers must not overlap on the same domain:

1. **Tunnel ingress** (Cloudflare dashboard): `hostname → local service`.
2. **Reverse proxy** (Caddy/Traefik): serves the request the tunnel forwards.

For `ladtc.be`, the tunnel pointed to `http://localhost:80` (= Caddy), but the
Caddyfile had no `ladtc.be` block. With Caddy's default `auto_https`, a request
arriving in plain HTTP (as the tunnel delivers it) gets redirected to HTTPS —
but Cloudflare already served HTTPS at the edge, so the client re-requests HTTPS,
the tunnel re-delivers HTTP, Caddy re-redirects → **infinite 308**.

> Same defect hit every public hostname the tunnel sent to `localhost:80`.

---

## Diagnosis playbook

### 1. Confirm it's a loop, not a 5xx
```bash
curl -sIL https://ladtc.be/ | grep -iE "^HTTP|location"   # repeated 308 → self
```

### 2. Is the app itself alive? (bypass Cloudflare/Caddy)
```bash
ssh homelab 'docker inspect <container> --format "{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}"'
ssh homelab 'curl -sI http://<container-ip>:<port>/'      # 200 = app healthy
```

### 3. What does the origin (Caddy) do for that Host?
```bash
ssh homelab 'curl -sI -H "Host: ladtc.be" http://localhost/'
# 308 + Server: Caddy  → Caddy is redirecting = the loop source
```

### 4. Read the real Caddy logs (NOT docker logs)
The Caddyfile has `log { output file /var/log/caddy/access.log }` — **all** logs
go to that file, `docker logs caddy` is nearly empty.
```bash
ssh homelab 'docker exec caddy tail -200 /var/log/caddy/access.log | grep -iE "error|obtain|challenge"'
```

### 5. Hairpin-NAT trap
Testing `curl http://<public-ip>:80` from a machine **on the same LAN** succeeds
(box hairpins the request) even when the port is closed from the real internet.
Let's Encrypt (external) is the ground truth — its ACME error
`Timeout during connect (likely firewall)` proves the port is not forwarded.

---

## Fixes applied

| Domain | Fix | Detail |
|---|---|---|
| `ladtc.be`, `www.ladtc.be` | publish port + tunnel direct | `docker-compose.coolify.yml` `ports: - "127.0.0.1:3000:3000"`, tunnel → `localhost:3000` |
| `git.anthemion.dev` | tunnel direct | Forgejo already published on `:32768` → tunnel → `localhost:32768` |
| `staging-portfolio.anthemion.dev` | tunnel direct (IP) | `10.0.1.4:80` (manual nginx container, port not published) |
| `uptime.anthemion.dev` | tunnel direct (IP) | `10.0.2.2:3001` (Coolify one-click service; port-publish via Coolify UI didn't apply) |
| `git.stephaneroos.com` | Caddy HTTP-only + tunnel | `http://git...` block → `localhost:32768`, tunnel → `localhost:80` |
| `photos.stephaneroos.com` | Caddy HTTP-only + tunnel | `http://photos...` block → `localhost:2284`, tunnel → `localhost:80` |

### Caddy changes (`configs/docker/Caddyfile`)
- `auto_https off` in the global block (TLS terminated at Cloudflare edge; no
  cert management, no `:443` listener, no HTTP→HTTPS redirect that would loop).
- Personal subdomains defined as `http://<host> { reverse_proxy ... }`.
- Corrected proxy targets: `git 3000→32768`, `photos 8080→2284`.
- `cloud`/`home` blocks commented (backing services not ready).
- apex/`www` blocks commented — those are **Obsidian Publish** (CNAME
  `publish-main.obsidian.md`), not Caddy.

### Deploy workflow for Caddyfile changes
```bash
# on the Mac (repo source of truth)
git add configs/docker/Caddyfile && git commit -m "..." && git push origin main
# on the NAS (caddy mounts the repo clone)
ssh homelab 'cd ~/homelab && git fetch origin && git checkout origin/main -- configs/docker/Caddyfile'
ssh homelab 'docker exec caddy caddy reload --config /etc/caddy/Caddyfile'
# NOTE: auto_https/listener changes need a full restart, not reload:
ssh homelab 'docker restart caddy'
```

---

## Final tunnel map (`6b5cb58d-…`)

| # | Hostname | Service | Status |
|---|---|---|---|
| 1 | `coolify.anthemion.dev` | `localhost:8000` | ✅ OK |
| 2 | `uptime.anthemion.dev` | `10.0.2.2:3001` | ✅ fixed |
| 3 | `cloud.anthemion.dev` | `localhost:11000` | ✅ OK |
| 4 | `staging-portfolio.anthemion.dev` | `10.0.1.4:80` | ✅ fixed |
| 5 | `staging-ladtc.anthemion.dev` | `localhost:80` (Caddy) | ❌ no staging container |
| 6 | `ladtc.be` | `localhost:3000` | ✅ fixed |
| 7 | `www.ladtc.be` | `localhost:3000` | ✅ fixed |
| 8 | `hillsrun.com` | `https://localhost:443` | ❌ likely broken (Caddy has no block) |
| 9 | `www.hillsrun.com` | `https://localhost:443` | ❌ likely broken |
| 10 | `aio.anthemion.dev` | `https://localhost:8181` | (unverified) |
| 11 | `ssh.anthemion.dev` | `ssh://localhost:22` | ✅ OK |
| 12 | `git.anthemion.dev` | `localhost:32768` | ✅ fixed |
| 13 | `cloud.ladtc.be` | `192.168.129.21:8181` | ❌ wrong IP (NAS is .10) |
| + | `git.stephaneroos.com` | `localhost:80` | ✅ fixed |
| + | `photos.stephaneroos.com` | `localhost:80` | ✅ fixed |
| — | `stephaneroos.com`, `www` | Obsidian Publish | do NOT add to tunnel |

Catch-all: `http_status 404`.

### Personal services host ports (for reference)
- Forgejo `git` → `localhost:32768`
- Immich `photos` → `localhost:2284`
- LADTC → `127.0.0.1:3000`
- Nextcloud AIO apache → `localhost:11000`
- Nextcloud personal mastercontainer → `127.0.0.1:8081` (admin) / `11001`

---

## Lessons

1. **Ingress ≠ reverse proxy.** When a domain loops 308 served fast by
   Cloudflare, suspect the tunnel forwarding to a proxy that doesn't know the
   host (and forces HTTPS). Check `Server:` header.
2. **Don't trust LAN tests for public reachability** — hairpin NAT lies. Use an
   external probe (Let's Encrypt, an online port checker, or a phone on 4G).
3. **Caddy logs are in the file**, not `docker logs`, when a global `log{}`
   block is set.
4. **`auto_https off`**, not just `http://` prefixes, is needed when TLS is at
   the edge — otherwise the redirect loops.
5. **Publish host ports (loopback) for durability** — Docker IPs are volatile.

---

## Remaining (non-blocking)

- `staging-ladtc.anthemion.dev`: deploy a staging container or remove the route.
- `hillsrun.com` / `www`: same diagnosis (HTTPS→Caddy, no block).
- `cloud.ladtc.be`: fix IP `192.168.129.21` → `.10`.
- `cloud.stephaneroos.com`: fix `cloud-stephaneroos-proxy` crash-loop
  (`nginx: unknown "nginx_proxy" variable`), then enable the Caddy block.
- `home.stephaneroos.com`: deploy Dashy, then enable the Caddy block.
- `data-mastery`: decide if it should be public (not in the tunnel today).
- Durability: publish host ports for `uptime` and `portfolio` (currently on
  volatile Docker IPs).
