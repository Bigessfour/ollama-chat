import logging
import time
import uuid

import structlog
from flask import Flask, g, request

from config.settings import Settings
from utils.metrics import is_probe_path, record_http_request
from utils.tracing import bind_trace_context


def configure_logging(settings: Settings) -> None:
    log_level = getattr(logging, settings.log_level.upper(), logging.INFO)

    def add_service_context(
        logger: structlog.types.WrappedLogger,
        method_name: str,
        event_dict: structlog.types.EventDict,
    ) -> structlog.types.EventDict:
        event_dict.setdefault("service", settings.app_name)
        event_dict.setdefault("environment", settings.app_env)
        event_dict.setdefault("version", settings.app_version)
        return event_dict

    shared_processors = [
        structlog.contextvars.merge_contextvars,
        add_service_context,
        structlog.processors.add_log_level,
        structlog.processors.TimeStamper(fmt="iso"),
        structlog.processors.StackInfoRenderer(),
    ]

    if settings.log_format == "console":
        processors = shared_processors + [
            structlog.dev.ConsoleRenderer(),
        ]
    else:
        processors = shared_processors + [
            structlog.processors.format_exc_info,
            structlog.processors.JSONRenderer(),
        ]

    structlog.configure(
        processors=processors,
        wrapper_class=structlog.make_filtering_bound_logger(log_level),
        context_class=dict,
        logger_factory=structlog.PrintLoggerFactory(),
        cache_logger_on_first_use=True,
    )

    logging.basicConfig(level=log_level)


def register_request_logging(app: Flask) -> None:
    logger = structlog.get_logger("http")

    @app.before_request
    def bind_request_context():
        request_id = request.headers.get("X-Request-ID", str(uuid.uuid4()))
        g.request_id = request_id
        g._request_start_time = time.perf_counter()
        structlog.contextvars.clear_contextvars()
        structlog.contextvars.bind_contextvars(request_id=request_id)
        bind_trace_context()
        logger.info(
            "request_started",
            method=request.method,
            path=request.path,
            route=request.endpoint,
        )

    @app.after_request
    def log_request_completed(response):
        duration_ms = None
        if hasattr(g, "_request_start_time"):
            duration_ms = round((time.perf_counter() - g._request_start_time) * 1000, 2)

        logger.info(
            "request_completed",
            method=request.method,
            path=request.path,
            route=request.endpoint,
            status=response.status_code,
            duration_ms=duration_ms,
        )

        settings = app.config["SETTINGS"]
        if duration_ms is not None and settings.metrics_enabled and not is_probe_path(request.path):
            record_http_request(
                settings,
                method=request.method,
                route=request.endpoint or "unknown",
                status_code=response.status_code,
                duration_ms=duration_ms,
            )

        response.headers["X-Request-ID"] = getattr(g, "request_id", "")
        return response
