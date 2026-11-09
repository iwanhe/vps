# Oracle APEX (Docker)

Self-hosted Oracle APEX: an Oracle Database container with APEX installed
into it, and an ORDS container that serves the APEX web UI.

- `db/` — `gvenzl/oracle-free:23-full-faststart` (Docker Hub, no Oracle
  account needed) plus Oracle APEX installed into the `FREEPDB1` pluggable
  database on first boot.
- `ords/` — Oracle REST Data Services, self-built from the official
  no-login ORDS/APEX zip downloads (Oracle's Free Use Terms and Conditions
  license), serving APEX on port 8080.

## Why "full" and not "slim"

The `slim` flavor of the Oracle Free image strips `rdbms/xml` and the XDK
to save space. Oracle APEX's installer prerequisite check requires those
(the XDB component shows up `INVALID` without them) and aborts before doing
anything — confirmed by actually running the install against both flavors.
Stick with `full`.

## Usage

```bash
cp .env.example .env
# edit .env — set real passwords

docker compose up -d --build
```

First boot installs Oracle APEX into the database, which takes a while
(tens of minutes) — watch progress with:

```bash
docker compose logs -f db
```

Once `db` reports healthy, `ords` installs its own schema and connection
pool against it (needs the `ORACLE_PASSWORD`/SYS password once, to create
its database objects) and starts serving:

```bash
docker compose logs -f ords
```

Open `http://<host>:8080/ords/` and log in to workspace `INTERNAL` as user
`ADMIN` with `APEX_ADMIN_PASSWORD` from `.env` to create your own workspace
and application.

## Notes

- Both the `db` and `ords` first-boot steps are one-shot: they're skipped
  on every later `docker compose up` because of marker files kept in the
  `db-data` and `ords-config` volumes. Remove those volumes to redo a
  from-scratch install.
- `ORACLE_PASSWORD` doubles as the ORDS install's SYS password.
- Three different database accounts need a password, and the whole stack
  is wired to keep them straight: `APEX_ADMIN_PASSWORD` is the APEX
  workspace admin (a human logs in with this one); `APEX_PUBLIC_USER_PASSWORD`
  is a real database account password both containers must agree on
  (ORDS's PL/SQL gateway connects to the DB as this user); `ORDS_PUBLIC_USER_PASSWORD`
  is managed entirely by the `ords` container itself, nothing on the `db`
  side needs to match it.
- Put a reverse proxy (nginx/Caddy) in front of `ords` for TLS on a real
  VPS; this compose file only exposes plain HTTP on 8080.
- This whole stack — `db`'s APEX install, `ords`'s schema install, and
  `ords serve` serving the login page and static assets — was run
  end-to-end against a live `gvenzl/oracle-free` container while building
  this, not just assembled from docs. Two things the docs/`--help` text
  don't make obvious, found that way:
  - `apxchpwd.sql`'s password prompt silently rejects every password when
    fed via a pipe/heredoc instead of a real TTY, which is why
    `apex-install.sh` calls the same admin-user API it calls internally,
    directly, instead of running that script.
  - `ords install --password-stdin` needs `--proxy-user` present even
    though you're not changing `ORDS_PUBLIC_USER`'s password through a
    flag of that name — without it, install fails (even on a schema that's
    never been installed before) with "Missing the ORDS_PUBLIC_USER
    password that is required to store in the configuration". With
    `--proxy-user` present, the three stdin lines are read in this order:
    admin (SYS), proxy-user (ORDS_PUBLIC_USER), gateway-user
    (APEX_PUBLIC_USER) — not the order the flags appear on the command
    line.
