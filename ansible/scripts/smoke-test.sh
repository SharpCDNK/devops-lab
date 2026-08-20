#!/usr/bin/env bash
# Smoke-тест после деплоя. Возвращает 0 если всё хорошо, 1 если нет.
# Запуск: ./smoke-test.sh http://51.68.143.214
set -uo pipefail

BASE="${1:-http://127.0.0.1}"
FAILED=0

check() {
  local name="$1" url="$2" expected="$3"
  local code
  code=$(curl -s -o /dev/null -w '%{http_code}' --max-time 10 "$url" || echo "000")
  if [[ "$code" == "$expected" ]]; then
    echo "  OK   $name ($code)"
  else
    echo "  FAIL $name (получено $code, ожидалось $expected)"
    FAILED=1
  fi
}

echo "Smoke-тест против ${BASE}"
check "root"   "${BASE}/"       200
check "health" "${BASE}/health" 200
check "ready"  "${BASE}/ready"  200
check "items"  "${BASE}/items"  200

# Проверяем, что запись в БД реально работает
resp=$(curl -s --max-time 10 -X POST "${BASE}/items" \
  -H 'Content-Type: application/json' \
  -d '{"name":"smoke-test"}' || echo "")
if echo "$resp" | grep -q '"id"'; then
  echo "  OK   POST /items"
else
  echo "  FAIL POST /items (ответ: ${resp:-пусто})"
  FAILED=1
fi

if (( FAILED )); then
  echo "SMOKE TEST FAILED"
  exit 1
fi
echo "SMOKE TEST PASSED"
