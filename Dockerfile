#syntax=docker/dockerfile:1
#Stage 1

FROM python:3.13-slim AS builder

ENV PIP_DISABLE_PIP_VERSHION_CHECK=1 \
    PIP_NO_CACHE_DIR=1

WORKDIR /build

#venv
RUN python -m venv /opt/venv/
ENV PATH="/opt/venv/bin:$PATH"
COPY app/requirements.txt .
RUN pip install -r requirements.txt

#Stage 2

FROM python:3.13-slim

LABEL org.opencontainers.image.source="https://github.com/SharpCDNK/devops-lab" \
      org.opencontainers.image.description="devops-lab demo service" \
      org.opencontainers.image.licenses="MIT"

RUN groupadd --system --gid 1001 app && useradd --system --uid 1001 --gid app --home-dir /app --no-create-home app

WORKDIR /app

COPY --from=builder /opt/venv /opt/venv
COPY --chown=app:app app/ ./app/

ENV PATH="/opt/venv/bin:$PATH" \
    PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    APP_VERSION=dev

USER app
EXPOSE 8000
STOPSIGNAL SIGTERM

HEALTHCHECK --interval=30s --timeout=3s --start-period=10s --retries=3 \
    CMD python -c "import urllib.request,sys; sys.exit(0 if urllib.request.urlopen('http://127.0.0.1:8000/health', timeout=2).status==200 else 1)"

ENTRYPOINT ["uvicorn", "app.main:app"]
CMD ["--host", "0.0.0.0", "--port", "8000", "--proxy-headers", "--forwarded-allow-ips", "*"]
