"""
devops-lab demo service.

Endpoints:
  GET  /            - краткая информация о сервисе
  GET  /health      - liveness: жив ли процесс (без внешних зависимостей)
  GET  /ready       - readiness: готов ли принимать трафик (проверяет БД)
  GET  /metrics     - метрики в формате Prometheus
  GET  /items       - список записей из БД
  POST /items       - создать запись
"""
import json
import logging
import os
import sys
import time
from contextlib import asynccontextmanager

import psycopg
from fastapi import FastAPI, HTTPException, Request, Response
from prometheus_client import CONTENT_TYPE_LATEST, Counter, Histogram, generate_latest
from pydantic import BaseModel

APP_VERSION = os.getenv("APP_VERSION", "dev")
DATABASE_URL = os.getenv("DATABASE_URL", "postgresql://app:app@localhost:5432/appdb")


# --- Структурированные логи в stdout (12-factor: логи как поток событий) ---
class JsonFormatter(logging.Formatter):
    def format(self, record: logging.LogRecord) -> str:
        payload = {
            "ts": time.strftime("%Y-%m-%dT%H:%M:%S", time.gmtime(record.created)),
            "level": record.levelname,
            "logger": record.name,
            "msg": record.getMessage(),
        }
        if hasattr(record, "extra"):
            payload.update(record.extra)
        return json.dumps(payload, ensure_ascii=False)


handler = logging.StreamHandler(sys.stdout)
handler.setFormatter(JsonFormatter())
logging.basicConfig(level=logging.INFO, handlers=[handler], force=True)
log = logging.getLogger("app")

# --- Метрики ---
REQUESTS = Counter(
    "app_http_requests_total", "Total HTTP requests", ["method", "path", "status"]
)
LATENCY = Histogram(
    "app_http_request_duration_seconds", "Request latency", ["method", "path"]
)


def db_connect():
    return psycopg.connect(DATABASE_URL, connect_timeout=3)


def init_db(retries: int = 15, delay: float = 2.0) -> None:
    """Приложение само переживает недоступность БД при старте (retry с backoff)."""
    for attempt in range(1, retries + 1):
        try:
            with db_connect() as conn, conn.cursor() as cur:
                cur.execute(
                    """
                    CREATE TABLE IF NOT EXISTS items (
                        id      SERIAL PRIMARY KEY,
                        name    TEXT NOT NULL,
                        created TIMESTAMPTZ NOT NULL DEFAULT now()
                    )
                    """
                )
                conn.commit()
            log.info("database ready")
            return
        except Exception as exc:  # noqa: BLE001
            log.warning("db not ready (attempt %s/%s): %s", attempt, retries, exc)
            time.sleep(delay)
    raise RuntimeError("database is not reachable after retries")


@asynccontextmanager
async def lifespan(_: FastAPI):
    if os.getenv("SKIP_DB_INIT") != "1":
        init_db()
    yield
    log.info("shutting down gracefully")


app = FastAPI(title="devops-lab", version=APP_VERSION, lifespan=lifespan)


@app.middleware("http")
async def metrics_middleware(request: Request, call_next):
    start = time.perf_counter()
    response = await call_next(request)
    elapsed = time.perf_counter() - start
    path = request.scope.get("route").path if request.scope.get("route") else "unmatched"
    REQUESTS.labels(request.method, path, response.status_code).inc()
    LATENCY.labels(request.method, path).observe(elapsed)
    log.info(
        "request",
        extra={
            "extra": {
                "method": request.method,
                "path": path,
                "status": response.status_code,
                "duration_ms": round(elapsed * 1000, 2),
            }
        },
    )
    return response


class Item(BaseModel):
    name: str


@app.get("/")
def root():
    return {"service": "devops-lab", "version": APP_VERSION}


@app.get("/health")
def health():
    """Liveness: процесс жив. Внешние зависимости здесь НЕ проверяем —
    иначе падение БД вызовет бесконечный рестарт контейнера."""
    return {"status": "ok"}


@app.get("/ready")
def ready():
    """Readiness: готов принимать трафик. Здесь БД проверяем."""
    try:
        with db_connect() as conn, conn.cursor() as cur:
            cur.execute("SELECT 1")
            cur.fetchone()
        return {"status": "ready"}
    except Exception as exc:  # noqa: BLE001
        raise HTTPException(status_code=503, detail=f"database unavailable: {exc}")


@app.get("/metrics")
def metrics():
    return Response(generate_latest(), media_type=CONTENT_TYPE_LATEST)


@app.get("/items")
def list_items():
    with db_connect() as conn, conn.cursor() as cur:
        cur.execute("SELECT id, name, created FROM items ORDER BY id DESC LIMIT 100")
        rows = cur.fetchall()
    return [{"id": r[0], "name": r[1], "created": r[2].isoformat()} for r in rows]


@app.post("/items", status_code=201)
def create_item(item: Item):
    with db_connect() as conn, conn.cursor() as cur:
        cur.execute("INSERT INTO items (name) VALUES (%s) RETURNING id", (item.name,))
        item_id = cur.fetchone()[0]
        conn.commit()
    return {"id": item_id, "name": item.name}
