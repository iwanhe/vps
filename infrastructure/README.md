# infrastructure/

Shared infrastructure for everything under `apps/` and `databases/` — not
an app or a database itself. Empty for now; filled in as later work
packages land:

| Folder (planned) | What it'll hold | Work package |
| --- | --- | --- |
| `proxy/caddy/` | Reverse proxy, automatic HTTPS, domain routing | WP3 |
| `monitoring/uptime-kuma/` | Availability checks | WP7 |
| `monitoring/prometheus/`, `monitoring/grafana/` | Metrics | WP8 |
| `logging/` | Centralized logs (Loki/Promtail) | WP9+ |
| `identity/authentik/` | SSO, if an app ends up needing it | WP9+ |
| `security/` | CrowdSec etc., if needed | WP9+ |
| `vpn/tailscale/` | Private admin access to SSH/DBs/dashboards | WP6 |

Why empty subfolders aren't created yet: an empty directory isn't
something Git can track, and a placeholder with no real config would just
be noise until the work package that actually needs it lands. See the
root [`README.md`](../README.md) for the full roadmap and current status.
