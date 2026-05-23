"""Optional OpenTelemetry tracing (disabled by default)."""

from __future__ import annotations

import structlog
from flask import Flask

from config.settings import Settings

_tracing_configured = False


def configure_tracing(app: Flask, settings: Settings) -> None:
    global _tracing_configured
    if not settings.otel_enabled or _tracing_configured:
        return

    from opentelemetry import trace
    from opentelemetry.instrumentation.flask import FlaskInstrumentor
    from opentelemetry.instrumentation.requests import RequestsInstrumentor
    from opentelemetry.sdk.resources import Resource
    from opentelemetry.sdk.trace import TracerProvider
    from opentelemetry.sdk.trace.export import BatchSpanProcessor

    resource = Resource.create(
        {
            "service.name": settings.otel_service_name,
            "deployment.environment": settings.app_env,
        }
    )
    provider = TracerProvider(resource=resource)

    if settings.otel_exporter == "otlp":
        from opentelemetry.exporter.otlp.proto.http.trace_exporter import (
            OTLPSpanExporter,
        )

        endpoint = settings.otel_exporter_otlp_endpoint
        if not endpoint:
            raise ValueError("OTEL_EXPORTER_OTLP_ENDPOINT is required when OTEL_EXPORTER=otlp")
        provider.add_span_processor(BatchSpanProcessor(OTLPSpanExporter(endpoint=endpoint)))
    else:
        from opentelemetry.sdk.trace.export import ConsoleSpanExporter

        provider.add_span_processor(BatchSpanProcessor(ConsoleSpanExporter()))

    trace.set_tracer_provider(provider)
    FlaskInstrumentor().instrument_app(app)
    RequestsInstrumentor().instrument()
    _tracing_configured = True

    structlog.get_logger(__name__).info(
        "tracing_enabled",
        exporter=settings.otel_exporter,
        service=settings.otel_service_name,
    )


def bind_trace_context() -> None:
    """Bind trace/span IDs into structlog context when tracing is active."""
    try:
        from opentelemetry import trace

        span = trace.get_current_span()
        ctx = span.get_span_context()
        if ctx.is_valid:
            structlog.contextvars.bind_contextvars(
                trace_id=format(ctx.trace_id, "032x"),
                span_id=format(ctx.span_id, "016x"),
            )
    except ImportError:
        pass
