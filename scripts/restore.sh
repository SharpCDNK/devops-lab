#!/usr/bin/env bash
# Восстановление БД из дампа. ВНИМАНИЕ: перезаписывает данные.
# Запуск: ./restore.sh /opt/backups/appdb_20260819_030000.sql.gz
set -euo pipefail

DUMP="${1:?usage: restore.sh <path-to-dump.sql.gz>}"
CONTAINER="${CONTAINER:-dl-db}"
ENV_FILE="${ENV_FILE:-/opt/devops-lab/.env}"

# shellcheck disable=SC1090
set -a; source "$ENV_FILE"; set +a

echo "Будет восстановлена БД '${POSTGRES_DB}' из ${DUMP}."
read -r -p "Продолжить? (yes/no) " answer
[[ "$answer" == "yes" ]] || { echo "отменено"; exit 1; }

gunzip -c "$DUMP" | docker exec -i "$CONTAINER" psql -U "$POSTGRES_USER" -d "$POSTGRES_DB"
echo "восстановление завершено"
