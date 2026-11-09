# vps

Docker setups for self-hosted services on this VPS, one folder per service.

## Prerequisites

Docker Engine with the Compose plugin (`docker compose version`) on the VPS.
Nothing else needs to be installed on the host — everything else builds
inside the containers.

## Services

| Folder | What it runs | Port |
| --- | --- | --- |
| [`nextjs/`](nextjs/) | A Next.js app (standalone Docker build) | 3000 |
| [`apex/`](apex/) | Oracle Database + ORDS, serving Oracle APEX | 8080 (APEX), 1521 (DB) |

Each folder is independent — its own `Dockerfile`(s) and `docker-compose.yml`,
run from inside that folder. See that folder's own `README.md` for details
specific to it; the quick start below covers the common case.

## Quick start

```bash
git clone <this-repo> vps
cd vps
```

### Next.js (`nextjs/`)

```bash
cd nextjs
docker compose up -d --build
```

Open `http://<host>:3000`.

### Oracle APEX (`apex/`)

```bash
cd apex
cp .env.example .env
# edit .env — set real passwords (see apex/README.md for what each one is for)
docker compose up -d --build
```

First boot installs Oracle APEX into the database, which takes tens of
minutes — watch progress with `docker compose logs -f db`, then
`docker compose logs -f ords`. Once ORDS reports it's initialized, open
`http://<host>:8080/ords/` and log in to workspace `INTERNAL` as `ADMIN`
with `APEX_ADMIN_PASSWORD` from `.env`.

Full details (why the DB image has to be the "full" flavor, what each
password in `.env` is actually for, how to redo the install from scratch)
are in [`apex/README.md`](apex/README.md).

## Running both at once

Both services bind their own ports (3000 vs 8080/1521) and have no shared
state, so `nextjs/` and `apex/` can run on the same VPS side by side —
just `docker compose up -d --build` in each folder. If you put a reverse
proxy (nginx/Caddy) in front for TLS/domains, route it to each service's
container port.
