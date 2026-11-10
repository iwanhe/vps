# Deploying to the VPS

`.github/workflows/deploy.yml` runs on every push to `main` (and can be
triggered manually from the Actions tab): it SSHes into the VPS, fetches
and hard-resets to `origin/main`, then runs `./scripts/deploy.sh`, which
rebuilds and (re)starts every service that already has a real `.env` —
anything still only configured via `.env.example` is skipped, not broken.

## One-time setup on the VPS

```bash
git clone <this-repo-url> /opt/vps   # or wherever you want it
cd /opt/vps
```

Create a dedicated deploy user (don't use `root` for this) with:
- A home directory and an `authorized_keys` entry for the deploy key
  below.
- Permission to run `docker`/`docker compose` (in the `docker` group).
- Write access to the repo path above.

## GitHub repository secrets

Settings → Secrets and variables → Actions, add:

| Secret | Value |
| --- | --- |
| `VPS_HOST` | The VPS's address (IP or hostname) |
| `VPS_USER` | The deploy user created above |
| `VPS_SSH_KEY` | The deploy user's **private** key (generate a new `ssh-keygen -t ed25519` pair just for this — don't reuse your own) |
| `VPS_REPO_PATH` | Where the repo was cloned, e.g. `/opt/vps` |
| `VPS_PORT` | Only if SSH isn't on port 22 |

Put the matching **public** key in that user's `~/.ssh/authorized_keys`
on the VPS.

## First deploy

Before the very first automated run, get everything to a known-good
state manually once:

```bash
cd /opt/vps
# for each service that needs one:
cp apps/apex/.env.example apps/apex/.env            # then edit it
cp databases/postgres/.env.example databases/postgres/.env
cp infrastructure/proxy/caddy/.env.example infrastructure/proxy/caddy/.env
./scripts/deploy.sh
```

After that, pushes to `main` keep it up to date automatically.

## What this was and wasn't validated against

- The SSH connection, remote command execution, and quoting (including a
  repo path containing a space, deliberately, as a stress test) were
  tested against a real `sshd` in a throwaway container — not just eyeballed.
- `scripts/deploy.sh`'s own logic (skips a service cleanly when its
  `.env` doesn't exist yet, continues past one service failing to build
  rather than aborting the rest, reports a non-zero exit if any failed)
  was run directly and confirmed with and without `.env` files present.
- The GitHub Actions workflow itself — actually running on a real
  `ubuntu-latest` runner against the real VPS — can't be tested from this
  sandbox. It depends on secrets that don't exist until you add them
  above. Trigger it manually (`workflow_dispatch`) for the first real run
  and watch its log before trusting it to run unattended on every push.
