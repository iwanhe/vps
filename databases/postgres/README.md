# PostgreSQL (Docker)

The official `postgres:17-alpine` image, with a persistent volume and a
healthcheck.

## Usage

```bash
cp .env.example .env
# edit .env — set real values

docker compose up -d
```

The port is bound to `127.0.0.1` only (not public). From the VPS itself,
connect with `psql` (or any Postgres client) using the
`POSTGRES_USER`/`POSTGRES_PASSWORD`/`POSTGRES_DB` from `.env`:

```bash
psql -h localhost -p 5432 -U <POSTGRES_USER> -d <POSTGRES_DB>
```

From elsewhere, open an SSH tunnel first, then connect to `localhost:5432`
as above:

```bash
ssh -L 5432:localhost:5432 <user>@<vps>
```

## Notes

- Data lives in the `postgres-data` named volume, so it survives
  `docker compose down` and container restarts — only `docker compose down
  -v` removes it.
- `POSTGRES_USER`/`POSTGRES_PASSWORD`/`POSTGRES_DB` only take effect the
  *first* time the container initializes an empty data directory. Changing
  `.env` later doesn't change an already-initialized database — use `psql`
  or `ALTER USER ... WITH PASSWORD` for that instead.
- For an app in another Docker Compose file on the same host to reach this
  one, either put both services in the same `docker compose` project/network,
  or connect to `localhost:5432` (or the VPS's address) like any other
  client — there's no default shared network between separate `docker
  compose up` projects.
- This isn't exposed with TLS. Postgres's own `sslmode=require` needs
  extra certificate setup this compose file doesn't do — the SSH tunnel
  above is what stands in for that.
