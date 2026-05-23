import time

from flask import Blueprint, current_app, jsonify

from app.extensions import limiter
from utils.exceptions import AppError, ModelNotReadyError, OllamaUnavailableError

health_bp = Blueprint("health", __name__)

_APP_START_TIME = time.time()


def _liveness_payload() -> dict:
    settings = current_app.config["SETTINGS"]
    return {
        "status": "ok",
        "service": settings.app_name,
        "version": settings.app_version,
        "environment": settings.app_env,
        "uptime_seconds": round(time.time() - _APP_START_TIME, 2),
    }


def _run_readiness_check() -> tuple[dict, int]:
    settings = current_app.config["SETTINGS"]
    ollama = current_app.config["OLLAMA_SERVICE"]
    start = time.perf_counter()
    try:
        result = ollama.check_ready()
        latency_ms = round((time.perf_counter() - start) * 1000, 2)
        checks = {
            "ollama": {
                "status": "ready",
                "latency_ms": latency_ms,
                "model": ollama.model,
            }
        }
        if settings.is_production:
            body = {
                "status": result.get("status", "ready"),
                "version": settings.app_version,
                "checks": checks,
            }
        else:
            body = {
                **result,
                "version": settings.app_version,
                "checks": checks,
            }
        return body, 200
    except (OllamaUnavailableError, ModelNotReadyError) as exc:
        latency_ms = round((time.perf_counter() - start) * 1000, 2)
        payload = {
            "status": "not_ready",
            "error": exc.message,
            "version": settings.app_version,
            "checks": {
                "ollama": {
                    "status": "not_ready",
                    "latency_ms": latency_ms,
                    "model": ollama.model,
                    "error": exc.message,
                }
            },
        }
        if not settings.is_production:
            payload["ollama"] = ollama.base_url
        return payload, exc.status_code
    except AppError as exc:
        return (
            {
                "status": "not_ready",
                "error": exc.message,
                "version": settings.app_version,
            },
            exc.status_code,
        )


@health_bp.get("/health")
@health_bp.get("/live")
@limiter.exempt
def liveness():
    """Liveness probe: process is running (no Ollama call)."""
    return jsonify(_liveness_payload())


@health_bp.get("/ready")
@limiter.limit(lambda: current_app.config["SETTINGS"].rate_limit_ready)
def readiness():
    """Readiness probe: Ollama is reachable and model is available."""
    body, status_code = _run_readiness_check()
    return jsonify(body), status_code
