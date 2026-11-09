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
- `ORACLE_PASSWORD` doubles as the ORDS install's SYS password. ORDS
  creates its own `ORDS_PUBLIC_USER` with a random, internally-managed
  password — you never need to know it.
- Put a reverse proxy (nginx/Caddy) in front of `ords` for TLS on a real
  VPS; this compose file only exposes plain HTTP on 8080.
- The `ords install` flags in `ords/entrypoint.sh` were taken from
  `ords install --help` on ORDS 26.3. If a much newer ORDS zip changes
  that CLI, re-check `docker compose run --rm ords ords install --help`.
