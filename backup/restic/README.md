# Backup (Restic)

Backs up Postgres and the Oracle database with a consistent logical
export first (`pg_dump` / `expdp`), not a raw copy of a data directory
while it's being written to — a raw copy can produce a backup that
silently fails to restore.

## Setup

```bash
cp .env.example .env
# edit .env:
#   RESTIC_REPOSITORY — off-box storage (S3, B2, SFTP, ...) on a real VPS;
#     a local path only works for testing
#   RESTIC_PASSWORD   — pick a strong one and store it somewhere else too;
#     lose it and the backups are unrecoverable, restic can't help
#   ORACLE_BACKUP_SCHEMAS — YOUR app's schema(s) in apex-db, not APEX_*
#     (those come back by reinstalling APEX, not by restoring a dump)
```

## Usage

```bash
./backup-postgres.sh
./backup-oracle.sh

# disaster recovery:
./restore-postgres.sh [snapshot-id]   # default: latest
./restore-oracle.sh [snapshot-id]     # default: latest
```

`backup-*.sh` also prunes old snapshots on every run
(`--keep-daily`/`--keep-weekly`/`--keep-monthly` from `.env`). Run them
on a schedule (cron, or a GitHub Actions scheduled workflow that SSHes in
like `deploy.yml` does) — nothing in this repo runs them automatically
yet.

## What each restore does to the target

- `restore-postgres.sh` **drops and recreates** `POSTGRES_DB`, then
  restores the dump into it.
- `restore-oracle.sh` imports with `table_exists_action=replace` into
  `ORACLE_BACKUP_SCHEMAS`, overwriting existing objects there.

Confirm `.env` points at what you mean before running either against
anything that matters.

## Validated how

Not just "the scripts look right" — actually run against live containers
while building this:

- **Postgres**: inserted a test row, ran `backup-postgres.sh`, dropped
  the table (simulating data loss), ran `restore-postgres.sh`, confirmed
  the row came back.
- **Oracle**: same cycle, but with `expdp`/`impdp` against a test schema
  in a fresh `gvenzl/oracle-free` container (not a full APEX install —
  the export/import mechanism doesn't care whether APEX is installed on
  top, and re-testing that would mean a ~20-minute APEX install just to
  re-prove a schema export/import). A nested-quoting bug (the first
  draft tried to embed a SQL*Plus heredoc inside a `docker exec bash -c
  '...'` string) only showed up once this was actually run — both
  `backup-oracle.sh` and `restore-oracle.sh` now write the inner script
  to a real file and `docker cp` it in instead, to avoid that whole class
  of bug.
