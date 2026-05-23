# Ollama Chat API (Backend)

Flask API that proxies chat requests to [Ollama](https://ollama.com). Designed for local development, Docker, and AWS deployment behind an Application Load Balancer.

---

## Project structure

```
backend/
├── app/                 # Application factory and extensions
│   ├── __init__.py      # create_app()
│   └── extensions.py    # Flask-Limiter
├── config/
│   └── settings.py      # pydantic-settings (environment-based)
├── routes/
│   ├── health.py        # /api/health, /api/ready
│   └── chat.py          # /api/chat
├── services/
│   └── ollama_service.py
├── utils/
│   ├── logging.py       # structlog (JSON or console)
│   └── exceptions.py    # Custom errors and handlers
├── tests/               # pytest suite
├── wsgi.py              # Gunicorn entry point
├── run.py               # Local dev server
├── gunicorn.conf.py
├── Dockerfile           # Multi-stage, non-root
├── .env.example
├── requirements.txt
└── requirements-dev.txt
```

---

## API endpoints

| Endpoint | Method | Purpose |
|----------|--------|---------|
| `/live`, `/health`, `/api/health` | GET | **Liveness** — process running (no Ollama call) |
| `/ready`, `/api/ready` | GET | **Readiness** — Ollama reachable and `OLLAMA_MODEL` available |
| `/api/chat` | POST | Proxies `{ "message": "..." }` to Ollama `/api/generate` (non-streaming) |

ALB health checks use `/api/ready`. Docker `HEALTHCHECK` uses `/live`. See [../docs/OPERATIONS.md](../docs/OPERATIONS.md).

### Example responses

**Liveness:**

```json
{"status": "ok", "service": "ollama-chat-api"}
```

**Readiness (success):**

```json
{
  "status": "ready",
  "ollama": "http://localhost:11434",
  "model": "gemma:2b",
  "ollama_status": 200,
  "models_available": ["gemma:2b"]
}
```

**Chat (success):**

```json
{"response": "Hello!", "model": "gemma:2b"}
```

**Error:**

```json
{"error": "Message is required"}
```

---

## Configuration

Copy the example environment file:

```bash
cp .env.example .env
```

| Variable | Default | Description |
|----------|---------|-------------|
| `APP_ENV` | `development` | `production` rejects `CORS_ORIGINS=*` |
| `OLLAMA_URL` | `http://localhost:11434` | Ollama base URL |
| `OLLAMA_MODEL` | `gemma:2b` | Model name for generate and readiness |
| `OLLAMA_TIMEOUT_SECONDS` | `5` | Timeout for tags/ready checks |
| `OLLAMA_GENERATE_TIMEOUT_SECONDS` | `120` | Timeout for chat generation |
| `LOG_LEVEL` | `INFO` | Logging level |
| `LOG_FORMAT` | `json` | `json` (production) or `console` (local) |
| `APP_VERSION` | `dev` | Reported in health and logs |
| `METRICS_ENABLED` | auto | `true` in production; EMF metrics to stdout |
| `METRICS_NAMESPACE` | `OllamaChat` | CloudWatch EMF namespace |
| `OTEL_ENABLED` | `false` | Enable OpenTelemetry tracing |
| `OTEL_EXPORTER` | `console` | `console` or `otlp` |
| `OTEL_EXPORTER_OTLP_ENDPOINT` | (unset) | Required when `OTEL_EXPORTER=otlp` |
| `CORS_ORIGINS` | `*` | Comma-separated origins (set to ALB URL in AWS); `*` rejected when `APP_ENV=production` |
| `API_KEY` | (unset) | If set, require `X-API-Key` on `POST /api/chat` (validated with `secrets.compare_digest`) |
| `REQUIRE_API_KEY_IN_PRODUCTION` | `false` | When `true` and `APP_ENV=production`, startup fails if `API_KEY` is unset |
| `TRUST_PROXY_COUNT` | `1` | ALB hop count for rate-limit client IP |
| `MAX_CONTENT_LENGTH` | `65536` | Max request body bytes |
| `RATE_LIMIT_DEFAULT` | `60 per minute` | Default rate limit |
| `RATE_LIMIT_CHAT` | `20 per minute` | Limit on `POST /api/chat` |
| `RATE_LIMIT_READY` | `120 per minute` | Limit on `GET /api/ready` |
| `GUNICORN_BIND` | `127.0.0.1:5000` | Use `0.0.0.0:5000` in Docker (see user-data) |
| `GUNICORN_WORKERS` | `2` | Gunicorn worker processes |
| `GUNICORN_THREADS` | `4` | Threads per worker (gthread) |
| `GUNICORN_GRACEFUL_TIMEOUT` | `30` | Graceful shutdown window (seconds) |

Security overview: [../SECURITY.md](../SECURITY.md).

---

## Local development

### Prerequisites

- Python 3.11+
- Ollama running locally with `gemma:2b`:

```bash
ollama pull gemma:2b
```

### Install and run

```bash
cd backend
python3.11 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
cp .env.example .env   # optional; set LOG_FORMAT=console for readable logs
python run.py
```

Server listens on http://0.0.0.0:5000.

### Gunicorn (production-like local)

```bash
gunicorn -c gunicorn.conf.py wsgi:app
```

### Docker

From the repository root:

```bash
docker build -t ollama-chat-backend ./backend
docker run -p 5002:5000 \
  -e OLLAMA_URL=http://host.docker.internal:11434 \
  -e LOG_FORMAT=console \
  ollama-chat-backend
```

Port **5002** on the host avoids macOS conflicts with services on 5000.

### Verify

```bash
curl http://localhost:5000/api/health
curl http://localhost:5000/api/ready
curl -X POST http://localhost:5000/api/chat \
  -H 'Content-Type: application/json' \
  -d '{"message":"Hello"}'
```

---

## Tests

```bash
cd backend
python3.11 -m venv .venv
source .venv/bin/activate
pip install -r requirements-dev.txt
pytest
```

---

## Production notes

- **ALB health checks:** Use `GET /api/ready` on port 5000 so instances are not registered until Ollama and the model are available. Use `/live` for container liveness.
- **Security headers:** CSP, `X-Frame-Options`, `X-Content-Type-Options`, `Permissions-Policy`; HSTS when `X-Forwarded-Proto: https` (after ALB HTTPS is enabled).
- **API key on AWS:** Terraform `TF_VAR_api_key` stores the key in SSM `/ollama-chat/api-key`; Flask user-data sets `API_KEY` and `REQUIRE_API_KEY_IN_PRODUCTION=true` when the parameter exists.
- **Rate limiting:** Uses in-memory storage per instance. For multi-instance production, configure Redis as the Flask-Limiter backend.
- **Container security:** Non-root `appuser` (UID 10001); EC2 runs with `--cap-drop=ALL` and `no-new-privileges` (see user-data).
- **Graceful shutdown:** Gunicorn `graceful_timeout` allows in-flight chat requests to complete on SIGTERM (e.g. instance refresh).
- **Logging:** Set `LOG_FORMAT=json` in production for structured logs (includes `service`, `environment`, `version`, `route`).
- **Metrics:** EMF lines to stdout (`METRICS_ENABLED`); see [../docs/OPERATIONS.md](../docs/OPERATIONS.md).
- **Tracing:** Optional via `OTEL_ENABLED=true`.

---

## Related documentation

- [../README.md](../README.md) — Project overview
- [../docs/ARCHITECTURE.md](../docs/ARCHITECTURE.md) — AWS topology
- [../docs/DEPLOYMENT.md](../docs/DEPLOYMENT.md) — Deploy runbook
