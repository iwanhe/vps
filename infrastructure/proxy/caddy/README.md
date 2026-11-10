# Caddy (reverse proxy + automatic HTTPS)

The single public entry point for every app — Caddy terminates TLS
(automatic Let's Encrypt certificates) and reverse-proxies to each app
over the shared `edge` Docker network by container name. Nothing else
in this repo publishes a port to the internet.

## Prerequisites

- A domain, with an A/AAAA record for each `*_DOMAIN` in `.env` pointing
  at this VPS's public IP. Automatic HTTPS needs real, resolvable DNS —
  it won't work against `localhost` or an IP address alone.
- Ports 80/tcp and 443/tcp (+443/udp for HTTP/3) open on the VPS firewall
  — see [`docs/security/baseline.md`](../../../docs/security/baseline.md).
- The services it proxies to already running and on the `edge` network
  (`apps/nextjs`, `apps/apex`'s `ords`) — see each one's own `README.md`.

## Usage

```bash
../../../scripts/create-edge-network.sh   # one-time, skip if already done

cp .env.example .env
# edit .env — real domains + an email for Let's Encrypt

docker compose up -d
docker compose logs -f caddy   # watch it request/renew certificates
```

Open `https://<NEXTJS_DOMAIN>` and `https://<APEX_DOMAIN>/ords/`.

## Adding another app

Add a new site block to the `Caddyfile`, add the matching env var, and
`docker compose up -d` again (Caddy reloads, no downtime):

```caddyfile
{$SOME_APP_DOMAIN} {
	reverse_proxy some-app-container-name:PORT
}
```

The target has to be reachable by container name, which means that
service's own `docker-compose.yml` needs to join the external `edge`
network too (see how `apps/nextjs` and `apex`'s `ords` do it).

## Notes

- Caddy's `email` directive is what Let's Encrypt uses for expiry
  warnings — it isn't shown to visitors.
- Certificates and Caddy's own state live in the `caddy-data`/
  `caddy-config` named volumes — they survive restarts, so Caddy doesn't
  re-request a certificate every time it restarts (Let's Encrypt rate
  limits fresh issuance per domain).
- The Caddyfile's syntax was checked with `caddy validate`; the
  reverse-proxy routing itself (does a request to Caddy actually reach
  the right backend container by name over `edge`) was tested against a
  stand-in container on that network before relying on the real apps.
