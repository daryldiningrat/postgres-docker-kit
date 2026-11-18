#!/usr/bin/env bash
# Logical backup: globals + one compressed custom-format dump per database.
# Usage: ./scripts/backup.sh   (override paths via .env)
set -euo pipefail

cd "$(dirname "$0")/.."
[ -f .env ] && set -a && . ./.env && set +a

CONTAINER="${CONTAINER_NAME:-postgres}"
SUPERUSER="${POSTGRES_USER:-postgres}"
BACKUP_DIR="${BACKUP_DIR:-./backups}"
RETENTION_DAYS="${BACKUP_RETENTION_DAYS:-14}"
TIMESTAMP="$(date +%Y%m%d-%H%M%S)"
TARGET="${BACKUP_DIR}/${TIMESTAMP}"

mkdir -p "$TARGET"

if ! docker exec "$CONTAINER" pg_isready -q -U "$SUPERUSER"; then
  echo "container '$CONTAINER' is not ready" >&2
  exit 1
fi

echo "Global objects (roles, tablespaces) ..."
docker exec "$CONTAINER" pg_dumpall -U "$SUPERUSER" --globals-only | gzip > "${TARGET}/globals.sql.gz"

DBS="$(docker exec "$CONTAINER" psql -U "$SUPERUSER" -d postgres -Atc \
  "SELECT datname FROM pg_database WHERE datistemplate = false AND datname NOT IN ('postgres')")"

for db in $DBS; do
  echo "Database ${db} ..."
  docker exec "$CONTAINER" pg_dump -U "$SUPERUSER" -Fc -d "$db" > "${TARGET}/${db}.dump"
done

( cd "$TARGET" && sha256sum ./* > SHA256SUMS )

# Prune old backup directories.
find "$BACKUP_DIR" -maxdepth 1 -type d -name '20*' -mtime "+${RETENTION_DAYS}" -exec rm -rf {} +

echo "Backup complete: ${TARGET}"
