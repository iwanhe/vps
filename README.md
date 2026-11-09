# vps

Self-hosted infrastructure platform for this VPS — app runtimes,
databases, and (as later work packages land) the shared infrastructure
that ties them together: reverse proxy/TLS, monitoring, backup, private
networking.

```
apps/            # application runtimes
  nextjs/
  apex/
databases/       # database services
  postgres/
infrastructure/  # shared infra (see infrastructure/README.md)
  proxy/caddy/   # the only public entry point
scripts/
  create-edge-network.sh
  deploy.sh      # run by .github/workflows/deploy.yml over SSH
docs/
  security/      # baseline.md — run once on the real VPS
  operations/    # deploy.md — GitHub Actions deploy setup
```

## Prerequisites

Docker Engine with the Compose plugin (`docker compose version`) on the
VPS. Nothing else needs to be installed on the host — everything else
builds inside the containers.

**Before exposing anything publicly**, see
[`docs/security/baseline.md`](docs/security/baseline.md) for the VPS-level
firewall setup. On the Docker side: `apps/nextjs` and `apex`'s `ords`
don't publish any port at all — they're only reachable through Caddy
(below) over a shared `edge` network, which has to exist first:

```bash
./scripts/create-edge-network.sh   # one-time
```

`apex`'s `db` and `databases/postgres` bind their ports to `127.0.0.1`
only (admin access via SSH tunnel) — see each folder's own `README.md`.

## Services

| Folder | What it runs | Port |
| --- | --- | --- |
| [`apps/nextjs/`](apps/nextjs/) | A Next.js app (standalone Docker build) | 3000 |
| [`apps/apex/`](apps/apex/) | Oracle Database + ORDS, serving Oracle APEX | 8080 (APEX), 1521 (DB) |
| [`databases/postgres/`](databases/postgres/) | PostgreSQL (official image) | 5432 |

Each folder is independent — its own `Dockerfile`(s) and
`docker-compose.yml`, run from inside that folder. See that folder's own
`README.md` for details specific to it; the quick start below covers the
common case.

## Quick start

```bash
git clone <this-repo> vps
cd vps
```

### Next.js (`apps/nextjs/`)

```bash
cd apps/nextjs
docker compose up -d --build
```

No port is published — it's only reachable through Caddy once that's set
up (below). For local testing without Caddy, see
[`apps/nextjs/README.md`](apps/nextjs/README.md).

### Oracle APEX (`apps/apex/`)

```bash
cd apps/apex
cp .env.example .env
# edit .env — set real passwords (see apps/apex/README.md for what each one is for)
docker compose up -d --build
```

First boot installs Oracle APEX into the database, which takes tens of
minutes — watch progress with `docker compose logs -f db`, then
`docker compose logs -f ords`. `ords` doesn't publish a port either — once
Caddy is set up and pointed at it, log in at your domain's `/ords/` path
to workspace `INTERNAL` as `ADMIN` with `APEX_ADMIN_PASSWORD` from `.env`.

Full details (why the DB image has to be the "full" flavor, what each
password in `.env` is actually for, how to redo the install from scratch)
are in [`apps/apex/README.md`](apps/apex/README.md).

### PostgreSQL (`databases/postgres/`)

```bash
cd databases/postgres
cp .env.example .env
# edit .env — set real values
docker compose up -d
```

The port is bound to `127.0.0.1` only — connect with `psql -h localhost -p
5432 -U <POSTGRES_USER> -d <POSTGRES_DB>` from the VPS itself, or via an
SSH tunnel from elsewhere. See
[`databases/postgres/README.md`](databases/postgres/README.md) for
details.

### Reverse proxy (`infrastructure/proxy/caddy/`)

The single public entry point, once a real domain is pointed at this VPS:

```bash
cd infrastructure/proxy/caddy
cp .env.example .env
# edit .env — real domains (with DNS already set up) + an email for Let's Encrypt
docker compose up -d
```

See [`infrastructure/proxy/caddy/README.md`](infrastructure/proxy/caddy/README.md)
for prerequisites (DNS, open ports) and how to add another app to it.

### Deploying from GitHub (`.github/workflows/deploy.yml`)

Pushes to `main` can deploy themselves — SSH into the VPS, pull, and run
`scripts/deploy.sh` (which skips any service that isn't configured yet
instead of breaking). See
[`docs/operations/deploy.md`](docs/operations/deploy.md) for the one-time
setup (a deploy user on the VPS, GitHub repository secrets) this needs
before the first run.

## Running them all at once

All three can run on the same VPS side by side with no conflicts: `apps/nextjs`
and `apex`'s `ords` share the `edge` network (fronted by Caddy, no direct
host port), while `apex`'s `db` and `databases/postgres` each bind their
own port to `127.0.0.1` only. Just `docker compose up -d --build` in each
folder, after `./scripts/create-edge-network.sh` once.

## Roadmap

This repo is growing from "a few Docker Compose files" into a proper
self-hosted platform, deliberately one piece at a time rather than all at
once:

| WP | What | Status |
| --- | --- | --- |
| WP1 | Repo restructure (`apps/`/`databases/`/`infrastructure/`) + security baseline | ✅ done |
| WP2 | Docker network isolation (stop publishing app/DB ports straight to the host) | ✅ done |
| WP3 | Caddy — reverse proxy, automatic HTTPS, domain routing | ✅ done |
| WP4 | GitHub Actions + SSH deploy runner | ✅ done |
| WP5 | Restic — backup & restore (including a safe Oracle backup method) | planned |
| WP6 | Tailscale — private admin access to SSH/DBs/dashboards | ⏭️ skipped for now |
| WP7 | Uptime Kuma — availability monitoring | ⏭️ skipped for now |
| WP8 | Prometheus + Grafana (or a lighter alternative) — metrics | ⏭️ skipped for now |
| WP9+ | Centralized logging, Authentik SSO, CrowdSec, Trivy | ⏭️ skipped for now |

See [`infrastructure/README.md`](infrastructure/README.md) for where each
of these will live once built.

### Skipped for now (WP6–WP9+)

Deliberately deferred — each has a plain workaround that covers the
same need without the extra service, until one of these stops being
enough:

- **WP6 (Tailscale)**: once WP2 lands, DB ports aren't published to the
  internet at all — an SSH tunnel (`ssh -L 5432:localhost:5432 ...`)
  covers occasional admin access. Revisit if that becomes a regular
  routine rather than occasional.
- **WP7 (Uptime Kuma)**: a free external checker (UptimeRobot, Better
  Uptime) covers "is it up" without self-hosting anything. Revisit if
  integrated alerting or not sending URLs to a third party matters.
- **WP8 (Prometheus + Grafana)**: `docker stats` covers "is a container
  eating resources" for this few services. Revisit only after an actual
  incident that a metrics history would have helped diagnose.
- **WP9+ (logging, Authentik, CrowdSec, Trivy)**: no app needs
  cross-service SSO or centralized logs yet, and there's no sign of
  active attacks to mitigate. Revisit if the number of apps makes
  per-app logins painful, or if logs genuinely need to be correlated
  across services to debug something.
