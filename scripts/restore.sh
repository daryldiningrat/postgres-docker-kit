#!/usr/bin/env bash
# Restore a single custom-format dump produced by backup.sh.
# Usage: ./scripts/restore.sh backups/<ts>/<db>.dump [target_db]
set -euo pipefail

cd "$(dirname "$0")/.."
[ -f .env ] && set -a && . ./.env && set +a

DUMP="${1:?usage: restore.sh <path-to-.dump> [target_db]}"
DB="${2:-${POSTGRES_DB:-appdb}}"
CONTAINER="${CONTAINER_NAME:-postgres}"
SUPERUSER="${POSTGRES_USER:-postgres}"

[ -f "$DUMP" ] || { echo "no such dump: $DUMP" >&2; exit 1; }

echo "Restoring ${DUMP} into '${DB}' ..."
docker exec -i "$CONTAINER" pg_restore -U "$SUPERUSER" -d "$DB" --clean --if-exists --no-owner < "$DUMP"
echo "Restore complete."
