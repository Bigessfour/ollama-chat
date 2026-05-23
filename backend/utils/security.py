import secrets
from functools import wraps

from flask import current_app, request

from utils.exceptions import AppError, UnauthorizedError


def register_security_headers(app) -> None:
    @app.after_request
    def add_security_headers(response):
        response.headers.setdefault("X-Content-Type-Options", "nosniff")
        response.headers.setdefault("X-Frame-Options", "DENY")
        response.headers.setdefault("Referrer-Policy", "strict-origin-when-cross-origin")
        response.headers.setdefault("X-Permitted-Cross-Domain-Policies", "none")
        response.headers.setdefault(
            "Permissions-Policy",
            "geolocation=(), microphone=(), camera=()",
        )
        response.headers.setdefault(
            "Content-Security-Policy",
            "default-src 'none'; frame-ancestors 'none'",
        )
        if request.headers.get("X-Forwarded-Proto", "").lower() == "https":
            response.headers.setdefault(
                "Strict-Transport-Security",
                "max-age=31536000; includeSubDomains",
            )
        return response


def require_api_key(view):
    @wraps(view)
    def wrapped(*args, **kwargs):
        settings = current_app.config["SETTINGS"]
        if settings.api_key is None:
            return view(*args, **kwargs)

        provided = request.headers.get("X-API-Key")
        if not provided or not secrets.compare_digest(provided, settings.api_key):
            raise UnauthorizedError("Invalid or missing API key")
        return view(*args, **kwargs)

    return wrapped


def require_json_content_type():
    content_type = request.content_type or ""
    if not content_type.startswith("application/json"):
        raise AppError("Content-Type must be application/json", status_code=415)
