from flask import Flask
from flask_cors import CORS
from werkzeug.middleware.proxy_fix import ProxyFix

from app.extensions import limiter
from config.settings import Settings, get_settings
from routes import chat_bp, health_bp
from services.ollama_service import OllamaService
from utils.exceptions import register_error_handlers
from utils.logging import configure_logging, register_request_logging
from utils.security import register_security_headers
from utils.tracing import configure_tracing


def create_app(settings: Settings | None = None) -> Flask:
    settings = settings or get_settings()

    configure_logging(settings)

    app = Flask(__name__)
    app.config["SETTINGS"] = settings
    app.config["MAX_CONTENT_LENGTH"] = settings.max_content_length

    ollama_service = OllamaService(settings)
    app.config["OLLAMA_SERVICE"] = ollama_service

    if settings.trust_proxy_count > 0:
        app.wsgi_app = ProxyFix(
            app.wsgi_app,
            x_for=settings.trust_proxy_count,
            x_proto=settings.trust_proxy_count,
            x_host=settings.trust_proxy_count,
        )

    CORS(
        app,
        origins=settings.cors_origins_list,
        methods=["GET", "POST", "OPTIONS"],
        allow_headers=["Content-Type", "X-API-Key"],
        supports_credentials=False,
        max_age=600,
    )

    limiter.init_app(app)
    app.config["RATELIMIT_DEFAULT"] = settings.rate_limit_default

    register_request_logging(app)
    register_error_handlers(app)
    register_security_headers(app)
    configure_tracing(app, settings)

    app.register_blueprint(health_bp, url_prefix="/api")
    app.register_blueprint(health_bp, url_prefix="", name="health_root")
    app.register_blueprint(chat_bp, url_prefix="/api")

    return app
