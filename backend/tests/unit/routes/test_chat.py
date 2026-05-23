from tests.fixtures.ollama import make_mock_ollama_service
from utils.exceptions import OllamaUnavailableError, OllamaUpstreamError


def test_chat_success(client, app, json_headers):
    mock_service = make_mock_ollama_service(
        generate_response={"response": "Hello there!", "model": "gemma:2b"},
    )
    app.config["OLLAMA_SERVICE"] = mock_service

    response = client.post(
        "/api/chat",
        json={"message": "Hi"},
        headers=json_headers,
    )
    assert response.status_code == 200
    data = response.get_json()
    assert data["response"] == "Hello there!"
    assert data["model"] == "gemma:2b"
    mock_service.generate.assert_called_once_with("Hi")


def test_chat_strips_message_whitespace(client, app, json_headers):
    mock_service = make_mock_ollama_service()
    app.config["OLLAMA_SERVICE"] = mock_service

    response = client.post(
        "/api/chat",
        json={"message": "  hello  "},
        headers=json_headers,
    )
    assert response.status_code == 200
    mock_service.generate.assert_called_once_with("hello")


def test_chat_empty_message(client, json_headers):
    response = client.post("/api/chat", json={"message": ""}, headers=json_headers)
    assert response.status_code == 400
    data = response.get_json()
    assert "error" in data


def test_chat_missing_body(client, json_headers):
    response = client.post("/api/chat", json={}, headers=json_headers)
    assert response.status_code == 400


def test_chat_ollama_unavailable(client, app, json_headers):
    mock_service = make_mock_ollama_service(
        generate_side_effect=OllamaUnavailableError("Ollama unreachable"),
    )
    app.config["OLLAMA_SERVICE"] = mock_service

    response = client.post(
        "/api/chat",
        json={"message": "Hi"},
        headers=json_headers,
    )
    assert response.status_code == 503


def test_chat_ollama_upstream_error(client, app, json_headers):
    mock_service = make_mock_ollama_service(
        generate_side_effect=OllamaUpstreamError("Upstream error"),
    )
    app.config["OLLAMA_SERVICE"] = mock_service

    response = client.post(
        "/api/chat",
        json={"message": "Hi"},
        headers=json_headers,
    )
    assert response.status_code == 502
