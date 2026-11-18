# Production PostgreSQL for a Homelab

A single-node, production-oriented PostgreSQL 17 stack for Docker / Docker Compose.
Tuned for a 14 GB RAM / 12 vCPU host with NVMe storage, with data checksums,
SCRAM auth, healthchecks, resource limits, tuned logging, and backup tooling.

## Layout

```
docker-compose.yml        PostgreSQL (and an optional pgAdmin profile)
.env / .env.example       Credentials and tunables
conf/postgresql.conf      Tuned server configuration
conf/pg_hba.conf          Client authentication rules
initdb/01-extensions.sql  Extensions created on first init
scripts/                  backup / restore / post-start helpers
Makefile                  Convenience targets
```

## Quick start

```bash
cp .env.example .env        # then edit POSTGRES_PASSWORD (a strong one is already generated)
make up                     # starts the container, waits for healthy, enables pg_stat_statements
make ps                     # verify it is up and healthy
```

By default the port is published on **127.0.0.1 only**. For LAN access set
`POSTGRES_BIND_ADDR=0.0.0.0` in `.env` and restart.

## Connecting

```bash
# from the host
psql "postgresql://postgres:<password>@127.0.0.1:5432/appdb"

# interactive shell via the container
make psql

# from another container on the same compose network
psql "postgresql://postgres:<password>@postgres:5432/appdb"
```

## What "production-grade" means here

- **Pinned image** (`postgres:17-bookworm`) — no surprise upgrades.
- **Data checksums** enabled at init (`--data-checksums`); they cannot be turned on later.
- **SCRAM-SHA-256** password auth for all TCP connections; only the in-container Unix socket is trusted.
- **Healthcheck** (`pg_isready`) so `depends_on` and `--wait` work correctly.
- **Resource limits** (6 CPU / 8 GB) so a runaway query cannot take down the host.
- **`shm_size: 2gb`** so parallel workers are not starved by Docker's 64 MB default.
- **Log rotation** via the `json-file` driver (10 MB × 5).
- **Graceful shutdown** with `stop_grace_period: 1m` for a clean fast shutdown.
- **Tuned config** (memory, WAL, planner for SSD, parallelism, autovacuum).
- **`pg_stat_statements`** preloaded and created on startup for query analytics.

## Backups

`scripts/backup.sh` writes globals plus one compressed custom-format dump per
database into `./backups/<timestamp>/`, with a `SHA256SUMS` manifest, and prunes
directories older than `BACKUP_RETENTION_DAYS`.

```bash
make backup
./scripts/restore.sh backups/20260101-030000/appdb.dump appdb
```

Schedule it with cron:

```cron
0 3 * * * cd /home/daryldiningrat/Apps/postgresql-local && ./scripts/backup.sh >> backups/backup.log 2>&1
```

For true point-in-time recovery, add WAL archiving (e.g. pgBackRest) — see the
commented `archive_mode` / `archive_command` lines in `conf/postgresql.conf`.

## Monitoring

```sql
-- slowest queries
SELECT calls, total_exec_time, mean_exec_time, query
FROM pg_stat_statements ORDER BY total_exec_time DESC LIMIT 10;

-- cache hit ratio
SELECT sum(blks_hit) / nullif(sum(blks_hit + blks_read), 0) AS cache_hit_ratio
FROM pg_stat_database;

-- table bloat / vacuum health
SELECT relname, n_dead_tup, last_autovacuum FROM pg_stat_user_tables
ORDER BY n_dead_tup DESC LIMIT 10;
```

## Operations

```bash
make logs        # tail container logs
make backup      # run an on-demand backup
make pull && make down && make up   # upgrade to a newer 17.x image
make down        # stop (data preserved in the 'pgdata' volume)
```

## pgAdmin (optional)

```bash
docker compose --profile admin up -d pgadmin   # http://127.0.0.1:5050
```

## Security notes

- `.env` is git-ignored — keep it that way and `chmod 600` it.
- Keep `POSTGRES_BIND_ADDR=127.0.0.1` unless you actually need LAN access; if you
  expose it, use a firewall and a long password.
- The `pgdata` volume holds everything. Back it up (or at least run `make backup`)
  before upgrades or host maintenance.

## Notes / tuning

- Memory and parallelism numbers in `conf/postgresql.conf` assume ~14 GB RAM.
  Re-tune `shared_buffers` / `effective_cache_size` / `max_parallel_workers` if
  the host changes.
- The named volume `pgdata` lives under `/var/lib/docker/volumes/pgdata`. To keep
  the data on a specific disk instead, replace the volume with a bind mount:
  `- /path/on/nvme/pgdata:/var/lib/postgresql/data`.
