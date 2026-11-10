# infrastructure/

Shared infrastructure for everything under `apps/` and `databases/` — not
an app or a database itself.

| Folder | What it holds | Work package | Status |
| --- | --- | --- | --- |
| [`proxy/caddy/`](proxy/caddy/) | Reverse proxy, automatic HTTPS, domain routing | WP3 | ✅ done |
| `monitoring/uptime-kuma/` | Availability checks | WP7 | ⏭️ skipped for now |
| `monitoring/prometheus/`, `monitoring/grafana/` | Metrics | WP8 | ⏭️ skipped for now |
| `logging/` | Centralized logs (Loki/Promtail) | WP9+ | ⏭️ skipped for now |
| `identity/authentik/` | SSO, if an app ends up needing it | WP9+ | ⏭️ skipped for now |
| `security/` | CrowdSec etc., if needed | WP9+ | ⏭️ skipped for now |
| `vpn/tailscale/` | Private admin access to SSH/DBs/dashboards | WP6 | ⏭️ skipped for now |

Why the skipped ones aren't even placeholder directories yet: an empty
directory isn't something Git can track, and a placeholder with no real
config would just be noise. See the root [`README.md`](../README.md) for
why each is deferred and what would make it worth revisiting.
