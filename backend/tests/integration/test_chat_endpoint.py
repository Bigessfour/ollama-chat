"""Integration tests for POST /api/chat through the full Flask stack."""

from __future__ import annotations

import pytest

from tests.fixtures.ollama import make_mock_ollama_service
from utils.exceptions import OllamaUnavailableError


@pytest.mark.integration
def test_chat_endpoint_full_round_trip(client, app, json_headers):
    """Mock Ollama at the service layer; exercise routing, validation, and JSON responses."""
    mock_service = make_mock_ollama_service(
        generate_response={
            "response": "Integration reply from mock Ollama",
            "model": "gemma:2b",
        },
    )
    app.config["OLLAMA_SERVICE"] = mock_service

    response = client.post(
        "/api/chat",
        headers=json_headers,
        json={"message": "Tell me a joke"},
    )

    assert response.status_code == 200
    assert response.content_type.startswith("application/json")

    data = response.get_json()
    assert data == {
        "response": "Integration reply from mock Ollama",
        "model": "gemma:2b",
    }
    mock_service.generate.assert_called_once_with("Tell me a joke")


@pytest.mark.integration
def test_chat_endpoint_propagates_ollama_failure(client, app, json_headers):
    mock_service = make_mock_ollama_service(
        generate_side_effect=OllamaUnavailableError("connection refused"),
    )
    app.config["OLLAMA_SERVICE"] = mock_service

    response = client.post(
        "/api/chat",
        headers=json_headers,
        json={"message": "ping"},
    )

    assert response.status_code == 503
    body = response.get_json()
    assert "error" in body
    assert "connection refused" in body["error"].lower()


@pytest.mark.integration
def test_chat_endpoint_requires_json_body(client, json_headers):
    response = client.post(
        "/api/chat",
        headers=json_headers,
        data="",
    )
    assert response.status_code == 400
