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
infrastructure/  # shared infra — empty until WP3+ (see infrastructure/README.md)
docs/
  security/      # baseline.md — run once on the real VPS
```

## Prerequisites

Docker Engine with the Compose plugin (`docker compose version`) on the
VPS. Nothing else needs to be installed on the host — everything else
builds inside the containers.

**Before exposing anything publicly**, see
[`docs/security/baseline.md`](docs/security/baseline.md) — right now every
service below publishes its ports straight to `0.0.0.0`; there's no
shared firewall or reverse proxy yet (that's WP2/WP3 below).

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

Open `http://<host>:3000`.

### Oracle APEX (`apps/apex/`)

```bash
cd apps/apex
cp .env.example .env
# edit .env — set real passwords (see apps/apex/README.md for what each one is for)
docker compose up -d --build
```

First boot installs Oracle APEX into the database, which takes tens of
minutes — watch progress with `docker compose logs -f db`, then
`docker compose logs -f ords`. Once ORDS reports it's initialized, open
`http://<host>:8080/ords/` and log in to workspace `INTERNAL` as `ADMIN`
with `APEX_ADMIN_PASSWORD` from `.env`.

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

Connect with `psql -h <host> -p 5432 -U <POSTGRES_USER> -d <POSTGRES_DB>`.
See [`databases/postgres/README.md`](databases/postgres/README.md) for
persistence and network notes.

## Running them all at once

Each service binds its own port(s) (3000, 8080/1521, 5432) and has no
shared state, so `apps/nextjs/`, `apps/apex/`, and `databases/postgres/`
can all run on the same VPS side by side — just `docker compose up -d
--build` in each folder. This is the current, temporary state: once WP2
(network isolation) and WP3 (Caddy) below land, these won't publish ports
straight to the host anymore.

## Roadmap

This repo is growing from "a few Docker Compose files" into a proper
self-hosted platform, deliberately one piece at a time rather than all at
once:

| WP | What | Status |
| --- | --- | --- |
| WP1 | Repo restructure (`apps/`/`databases/`/`infrastructure/`) + security baseline | ✅ done |
| WP2 | Docker network isolation (stop publishing app/DB ports straight to the host) | planned |
| WP3 | Caddy — reverse proxy, automatic HTTPS, domain routing | planned |
| WP4 | GitHub Actions + SSH deploy runner | planned |
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
