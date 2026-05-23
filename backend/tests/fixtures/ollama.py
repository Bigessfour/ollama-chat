"""Shared Ollama mocks for route and integration tests."""

from __future__ import annotations

from unittest.mock import MagicMock

from utils.exceptions import ModelNotReadyError, OllamaUnavailableError, OllamaUpstreamError


def make_mock_ollama_service(
    *,
    model: str = "gemma:2b",
    base_url: str = "http://mock-ollama:11434",
    generate_response: dict | None = None,
    generate_side_effect: Exception | None = None,
    ready_response: dict | None = None,
    ready_side_effect: Exception | None = None,
) -> MagicMock:
    service = MagicMock()
    service.model = model
    service.base_url = base_url

    if ready_side_effect is not None:
        service.check_ready.side_effect = ready_side_effect
    else:
        service.check_ready.return_value = ready_response or {
            "status": "ready",
            "ollama": base_url,
            "model": model,
            "ollama_status": 200,
            "models_available": [model],
        }

    if generate_side_effect is not None:
        service.generate.side_effect = generate_side_effect
    else:
        service.generate.return_value = generate_response or {
            "response": "Mock assistant reply",
            "model": model,
        }

    return service


__all__ = [
    "ModelNotReadyError",
    "OllamaUnavailableError",
    "OllamaUpstreamError",
    "make_mock_ollama_service",
]
