#!/usr/bin/env bash
# Idempotent post-start steps that cannot run during initdb.
# Currently: create the pg_stat_statements extension in the main database.
set -euo pipefail

cd "$(dirname "$0")/.."
[ -f .env ] && set -a && . ./.env && set +a

CONTAINER="${CONTAINER_NAME:-postgres}"
SUPERUSER="${POSTGRES_USER:-postgres}"
DB="${POSTGRES_DB:-appdb}"

docker exec "$CONTAINER" psql -v ON_ERROR_STOP=1 -U "$SUPERUSER" -d "$DB" \
  -c "CREATE EXTENSION IF NOT EXISTS pg_stat_statements;"

echo "pg_stat_statements ready in '${DB}'."
