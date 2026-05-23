# syntax=docker/dockerfile:1
# Pin by digest for supply-chain hardening, e.g.:
# FROM python:3.11-slim@sha256:<digest> AS builder

FROM python:3.11-slim AS builder

WORKDIR /build

RUN pip install --no-cache-dir --upgrade pip

COPY requirements.txt .
RUN pip install --no-cache-dir --prefix=/install -r requirements.txt

FROM python:3.11-slim AS runtime

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1 \
    PATH="/install/bin:$PATH" \
    PYTHONPATH="/install/lib/python3.11/site-packages"

WORKDIR /app

RUN apt-get update \
    && apt-get install -y --no-install-recommends ca-certificates \
    && rm -rf /var/lib/apt/lists/* \
    && groupadd --gid 10001 appuser \
    && useradd --uid 10001 --gid 10001 --create-home --shell /usr/sbin/nologin appuser

COPY --from=builder /install /install
RUN chown -R appuser:appuser /install

COPY --chown=appuser:appuser app ./app
COPY --chown=appuser:appuser config ./config
COPY --chown=appuser:appuser routes ./routes
COPY --chown=appuser:appuser services ./services
COPY --chown=appuser:appuser utils ./utils
COPY --chown=appuser:appuser wsgi.py gunicorn.conf.py ./

USER appuser

EXPOSE 5000

HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD python -c "import urllib.request; urllib.request.urlopen('http://127.0.0.1:5000/live', timeout=3)" || exit 1

CMD ["gunicorn", "-c", "gunicorn.conf.py", "wsgi:app"]
