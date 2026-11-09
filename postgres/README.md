# PostgreSQL (Docker)

The official `postgres:17-alpine` image, with a persistent volume and a
healthcheck.

## Usage

```bash
cp .env.example .env
# edit .env — set real values

docker compose up -d
```

Connect with `psql` (or any Postgres client) at `localhost:5432` using the
`POSTGRES_USER`/`POSTGRES_PASSWORD`/`POSTGRES_DB` from `.env`:

```bash
psql -h localhost -p 5432 -U <POSTGRES_USER> -d <POSTGRES_DB>
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
- This isn't exposed with TLS. For access from outside the VPS, prefer an
  SSH tunnel or a VPN over opening 5432 to the internet; Postgres's own
  `sslmode=require` needs extra certificate setup this compose file doesn't
  do.
