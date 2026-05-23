"""Shared pytest fixtures for backend tests."""

from __future__ import annotations

import pytest

from app import create_app
from config.settings import Settings
from tests.fixtures.ollama import make_mock_ollama_service


@pytest.fixture
def settings():
    return Settings(
        ollama_url="http://mock-ollama:11434",
        ollama_model="gemma:2b",
        log_format="console",
        log_level="WARNING",
        metrics_enabled=False,
        otel_enabled=False,
    )


@pytest.fixture
def mock_ollama_service():
    return make_mock_ollama_service()


@pytest.fixture
def app(settings, mock_ollama_service):
    application = create_app(settings)
    application.config["TESTING"] = True
    application.config["RATELIMIT_ENABLED"] = False
    application.config["OLLAMA_SERVICE"] = mock_ollama_service
    return application


@pytest.fixture
def client(app):
    return app.test_client()


@pytest.fixture
def json_headers():
    return {"Content-Type": "application/json"}
