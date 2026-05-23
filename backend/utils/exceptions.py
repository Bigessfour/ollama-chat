from flask import Flask, jsonify
import structlog

logger = structlog.get_logger(__name__)


class AppError(Exception):
    """Base application error with HTTP status."""

    status_code: int = 500

    def __init__(self, message: str, status_code: int | None = None):
        super().__init__(message)
        self.message = message
        if status_code is not None:
            self.status_code = status_code


class ValidationError(AppError):
    status_code = 400


class UnauthorizedError(AppError):
    status_code = 401


class OllamaUnavailableError(AppError):
    status_code = 503


class OllamaUpstreamError(AppError):
    status_code = 502


class ModelNotReadyError(AppError):
    status_code = 503


def _error_response(message: str, status_code: int):
    return jsonify({"error": message}), status_code


def register_error_handlers(app: Flask) -> None:
    @app.errorhandler(UnauthorizedError)
    def handle_unauthorized(exc: UnauthorizedError):
        logger.warning("unauthorized", error=exc.message)
        return _error_response(exc.message, exc.status_code)

    @app.errorhandler(ValidationError)
    def handle_validation_error(exc: ValidationError):
        logger.warning("validation_error", error=exc.message)
        return _error_response(exc.message, exc.status_code)

    @app.errorhandler(OllamaUnavailableError)
    def handle_ollama_unavailable(exc: OllamaUnavailableError):
        logger.warning("ollama_unavailable", error=exc.message)
        return _error_response(exc.message, exc.status_code)

    @app.errorhandler(ModelNotReadyError)
    def handle_model_not_ready(exc: ModelNotReadyError):
        logger.info("model_not_ready", error=exc.message)
        return _error_response(exc.message, exc.status_code)

    @app.errorhandler(OllamaUpstreamError)
    def handle_ollama_upstream(exc: OllamaUpstreamError):
        logger.error("ollama_upstream_error", error=exc.message)
        return _error_response(exc.message, exc.status_code)

    @app.errorhandler(AppError)
    def handle_app_error(exc: AppError):
        if exc.status_code >= 500:
            logger.exception("app_error", error=exc.message)
        else:
            logger.warning("app_error", error=exc.message)
        return _error_response(exc.message, exc.status_code)

    @app.errorhandler(429)
    def handle_rate_limit(exc):
        description = getattr(exc, "description", "Rate limit exceeded")
        logger.warning("rate_limit_exceeded", error=description)
        return _error_response(description, 429)

    @app.errorhandler(404)
    def handle_not_found(_exc):
        return _error_response("Not found", 404)

    @app.errorhandler(500)
    def handle_internal_error(_exc):
        logger.exception("internal_server_error")
        return _error_response("Internal server error", 500)
