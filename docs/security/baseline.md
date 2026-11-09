# Security baseline (WP1)

Run this once on the actual VPS — none of it can be done from this repo
or from a sandbox, it has to run on the real machine with root/sudo.

## Firewall (ufw)

Right now `apps/nextjs`, `apps/apex`, and `databases/postgres` each
publish their ports straight to `0.0.0.0` in their own
`docker-compose.yml`. Until WP2 (Docker network isolation) and WP3
(Caddy) land, that means **anyone on the internet can reach them** if the
VPS's firewall allows it. Lock it down now regardless of what Docker is
doing:

```bash
# Install if not already present
sudo apt-get update && sudo apt-get install -y ufw

# Default: deny everything inbound, allow everything outbound
sudo ufw default deny incoming
sudo ufw default allow outgoing

# SSH — required, or you lock yourself out
sudo ufw allow 22/tcp

# Only open these if you need the app reachable from the public internet
# right now. Prefer leaving them closed and using an SSH tunnel or
# Tailscale (WP6) until Caddy (WP3) is the single public entry point.
# sudo ufw allow 3000/tcp   # nextjs — direct access
# sudo ufw allow 8080/tcp   # apex/ords — direct access
# Never open these to 0.0.0.0/0:
#   1521/tcp (Oracle), 5432/tcp (Postgres) — database ports, admin-only

sudo ufw enable
sudo ufw status verbose
```

Once WP3 (Caddy) is in place, the plan is: only 80/tcp and 443/tcp (plus
22/tcp for SSH) stay open to the public internet, and every app/database
port above closes — Caddy becomes the only public door, and database
ports become reachable only over Tailscale (WP6) or an SSH tunnel.

## Secrets

Every service's real `.env` (`apps/apex/.env`, `databases/postgres/.env`,
etc.) is covered by the root [`.gitignore`](../../.gitignore) — only the
`.env.example` templates are committed. Before `docker compose up`,
double check with `git status` that no `.env` file is showing up as
untracked-and-about-to-be-added by a stray `git add -A`.

## SSH

Quick wins, do these if not already done:

```bash
# Key-based auth only
sudo sed -i 's/^#\?PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config
sudo sed -i 's/^#\?PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config
sudo systemctl restart sshd
```

Confirm you can still log in with your key in a **second terminal**
before closing the one you used to make this change.

## OS patches

```bash
sudo apt-get install -y unattended-upgrades
sudo dpkg-reconfigure --priority=low unattended-upgrades
```

## Not in WP1

Intrusion detection (CrowdSec/fail2ban), centralized log review, and
automated vulnerability scanning (Trivy) are later work packages — this
baseline is just "don't be wide open" while the rest of the platform gets
built.
