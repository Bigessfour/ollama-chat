import pytest

from app import create_app
from config.settings import Settings
from tests.fixtures.ollama import make_mock_ollama_service


def test_security_headers_present(client):
    response = client.get("/api/health")
    assert response.status_code == 200
    assert response.headers.get("X-Content-Type-Options") == "nosniff"
    assert response.headers.get("X-Frame-Options") == "DENY"
    assert response.headers.get("X-Permitted-Cross-Domain-Policies") == "none"
    assert "default-src 'none'" in response.headers.get("Content-Security-Policy", "")


def test_production_rejects_wildcard_cors():
    with pytest.raises(ValueError, match="CORS_ORIGINS"):
        Settings(app_env="production", cors_origins="*")


def test_production_can_require_api_key():
    with pytest.raises(ValueError, match="API_KEY"):
        Settings(
            app_env="production",
            cors_origins="http://alb.example.com",
            require_api_key_in_production=True,
        )


def test_cors_origin_must_be_url():
    with pytest.raises(ValueError, match="http://"):
        Settings(cors_origins="not-a-url")


def test_api_key_required_when_configured():
    settings = Settings(
        ollama_url="http://mock-ollama:11434",
        log_format="console",
        log_level="WARNING",
        api_key="test-secret-key",
        metrics_enabled=False,
    )
    app = create_app(settings)
    app.config["TESTING"] = True
    app.config["RATELIMIT_ENABLED"] = False
    mock_service = make_mock_ollama_service(
        generate_response={"response": "ok", "model": "gemma:2b"},
    )
    app.config["OLLAMA_SERVICE"] = mock_service
    test_client = app.test_client()

    response = test_client.post("/api/chat", json={"message": "hi"})
    assert response.status_code == 401

    response = test_client.post(
        "/api/chat",
        json={"message": "hi"},
        headers={"X-API-Key": "test-secret-key", "Content-Type": "application/json"},
    )
    assert response.status_code == 200


def test_max_content_length(client, app):
    app.config["MAX_CONTENT_LENGTH"] = 32
    response = client.post(
        "/api/chat",
        data="x" * 64,
        content_type="application/json",
    )
    assert response.status_code == 413


def test_chat_rejects_non_json_content_type(client):
    response = client.post(
        "/api/chat",
        data='{"message":"hi"}',
        content_type="text/plain",
    )
    assert response.status_code == 415


def test_chat_rejects_invalid_json(client):
    response = client.post(
        "/api/chat",
        data="{not json",
        content_type="application/json",
    )
    assert response.status_code == 400
