import pytest

from tests.fixtures.ollama import make_mock_ollama_service
from utils.exceptions import ModelNotReadyError, OllamaUnavailableError


@pytest.mark.parametrize("path", ["/api/health", "/health", "/live"])
def test_liveness_paths(client, path):
    response = client.get(path)
    assert response.status_code == 200
    data = response.get_json()
    assert data["status"] == "ok"
    assert data["service"] == "ollama-chat-api"
    assert "version" in data
    assert "uptime_seconds" in data
    assert data["uptime_seconds"] >= 0


@pytest.mark.parametrize("path", ["/api/ready", "/ready"])
def test_ready_success(client, app, path):
    mock_service = make_mock_ollama_service()
    app.config["OLLAMA_SERVICE"] = mock_service

    response = client.get(path)
    assert response.status_code == 200
    data = response.get_json()
    assert data["status"] == "ready"
    assert data["checks"]["ollama"]["status"] == "ready"
    assert data["checks"]["ollama"]["model"] == "gemma:2b"
    assert "latency_ms" in data["checks"]["ollama"]
    mock_service.check_ready.assert_called_once()


def test_ready_ollama_unavailable(client, app):
    mock_service = make_mock_ollama_service(
        ready_side_effect=OllamaUnavailableError("Ollama unreachable"),
    )
    app.config["OLLAMA_SERVICE"] = mock_service

    response = client.get("/api/ready")
    assert response.status_code == 503
    data = response.get_json()
    assert data["status"] == "not_ready"
    assert "unreachable" in data["error"].lower()
    assert data["checks"]["ollama"]["status"] == "not_ready"


def test_ready_model_not_ready(client, app):
    mock_service = make_mock_ollama_service(
        ready_side_effect=ModelNotReadyError("Model not available"),
    )
    app.config["OLLAMA_SERVICE"] = mock_service

    response = client.get("/ready")
    assert response.status_code == 503
    data = response.get_json()
    assert data["status"] == "not_ready"
    assert data["checks"]["ollama"]["status"] == "not_ready"
