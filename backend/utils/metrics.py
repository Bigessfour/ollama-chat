"""CloudWatch Embedded Metric Format (EMF) helpers."""

from __future__ import annotations

import json
import sys
import time
from typing import Any

from config.settings import Settings

# Paths excluded from HTTP request metrics (high-frequency probes).
_PROBE_PATHS = frozenset(
    {
        "/live",
        "/health",
        "/ready",
        "/api/health",
        "/api/ready",
    }
)


def is_probe_path(path: str) -> bool:
    return path in _PROBE_PATHS


def emit_emf(
    settings: Settings,
    metric_defs: list[dict[str, str]],
    dimensions: dict[str, str],
    values: dict[str, float | int],
) -> None:
    """Emit a single EMF JSON line to stdout for CloudWatch Logs metric extraction."""
    if not settings.metrics_enabled:
        return

    dimension_keys = list(dimensions.keys())
    doc: dict[str, Any] = {
        "_aws": {
            "Timestamp": int(time.time() * 1000),
            "CloudWatchMetrics": [
                {
                    "Namespace": settings.metrics_namespace,
                    "Dimensions": [dimension_keys],
                    "Metrics": metric_defs,
                }
            ],
        },
        **dimensions,
        **values,
    }
    sys.stdout.write(json.dumps(doc) + "\n")
    sys.stdout.flush()


def record_http_request(
    settings: Settings,
    *,
    method: str,
    route: str,
    status_code: int,
    duration_ms: float,
) -> None:
    base_dims = {
        "Service": settings.app_name,
        "Environment": settings.app_env,
        "Method": method,
        "Route": route or "unknown",
        "StatusCode": str(status_code),
    }
    emit_emf(
        settings,
        metric_defs=[
            {"Name": "HttpRequestCount", "Unit": "Count"},
            {"Name": "HttpRequestLatencyMs", "Unit": "Milliseconds"},
        ],
        dimensions=base_dims,
        values={
            "HttpRequestCount": 1,
            "HttpRequestLatencyMs": duration_ms,
        },
    )


def record_ollama_generate(
    settings: Settings,
    *,
    model: str,
    outcome: str,
    duration_ms: float,
) -> None:
    emit_emf(
        settings,
        metric_defs=[
            {"Name": "OllamaGenerateCount", "Unit": "Count"},
            {"Name": "OllamaGenerateLatencyMs", "Unit": "Milliseconds"},
        ],
        dimensions={
            "Service": settings.app_name,
            "Environment": settings.app_env,
            "Model": model,
            "Outcome": outcome,
        },
        values={
            "OllamaGenerateCount": 1,
            "OllamaGenerateLatencyMs": duration_ms,
        },
    )
