#!/usr/bin/env bash
# Бэкап PostgreSQL из контейнера + ротация.
# Запуск: BACKUP_DIR=/opt/backups KEEP_DAYS=7 ./backup.sh
set -euo pipefail

BACKUP_DIR="${BACKUP_DIR:-/opt/backups}"
KEEP_DAYS="${KEEP_DAYS:-7}"
CONTAINER="${CONTAINER:-dl-db}"
ENV_FILE="${ENV_FILE:-/opt/devops-lab/.env}"

log() { echo "[$(date -u +'%Y-%m-%dT%H:%M:%SZ')] $*"; }

[[ -f "$ENV_FILE" ]] || { log "ERROR: no env file $ENV_FILE"; exit 1; }
# shellcheck disable=SC1090
set -a; source "$ENV_FILE"; set +a

docker inspect "$CONTAINER" >/dev/null 2>&1 || { log "ERROR: container $CONTAINER not found"; exit 1; }

mkdir -p "$BACKUP_DIR"
STAMP="$(date -u +%Y%m%d_%H%M%S)"
FILE="${BACKUP_DIR}/${POSTGRES_DB}_${STAMP}.sql.gz"

log "dumping ${POSTGRES_DB} -> ${FILE}"
docker exec "$CONTAINER" pg_dump -U "$POSTGRES_USER" -d "$POSTGRES_DB" \
  | gzip -9 > "$FILE"

# Пустой дамп = провалившийся бэкап. Молча такое пропускать нельзя.
SIZE=$(stat -c%s "$FILE")
if (( SIZE < 1000 )); then
  log "ERROR: dump suspiciously small (${SIZE} bytes), removing"
  rm -f "$FILE"
  exit 1
fi

log "ok, size ${SIZE} bytes"

log "rotating backups older than ${KEEP_DAYS} days"
find "$BACKUP_DIR" -name "*.sql.gz" -type f -mtime "+${KEEP_DAYS}" -print -delete

log "done. current backups:"
ls -lh "$BACKUP_DIR" | tail -n +2
