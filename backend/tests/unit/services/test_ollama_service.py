from unittest.mock import MagicMock

import pytest
import requests

from config.settings import Settings
from services.ollama_service import OllamaService
from utils.exceptions import ModelNotReadyError, OllamaUnavailableError, OllamaUpstreamError


@pytest.fixture
def service_settings():
    return Settings(
        ollama_url="http://localhost:11434",
        ollama_model="gemma:2b",
        ollama_timeout_seconds=5,
        ollama_generate_timeout_seconds=120,
        metrics_enabled=False,
    )


@pytest.fixture
def session(mocker):
    return mocker.Mock(spec=requests.Session)


def test_check_ready_success(service_settings, session):
    response = MagicMock()
    response.ok = True
    response.status_code = 200
    response.json.return_value = {"models": [{"name": "gemma:2b"}]}
    session.get.return_value = response

    service = OllamaService(service_settings, session=session)
    result = service.check_ready()

    assert result["status"] == "ready"
    assert result["model"] == "gemma:2b"
    session.get.assert_called_once_with(
        "http://localhost:11434/api/tags",
        timeout=5,
    )


def test_check_ready_model_missing(service_settings, session):
    response = MagicMock()
    response.ok = True
    response.status_code = 200
    response.json.return_value = {"models": [{"name": "llama3.2:1b"}]}
    session.get.return_value = response

    service = OllamaService(service_settings, session=session)
    with pytest.raises(ModelNotReadyError):
        service.check_ready()


def test_check_ready_connection_error(service_settings, session):
    session.get.side_effect = requests.ConnectionError("refused")

    service = OllamaService(service_settings, session=session)
    with pytest.raises(OllamaUnavailableError):
        service.check_ready()


def test_check_ready_bad_status(service_settings, session):
    response = MagicMock()
    response.ok = False
    response.status_code = 500
    session.get.return_value = response

    service = OllamaService(service_settings, session=session)
    with pytest.raises(OllamaUpstreamError):
        service.check_ready()


def test_generate_success(service_settings, session):
    response = MagicMock()
    response.ok = True
    response.json.return_value = {"response": "Generated text"}
    session.post.return_value = response

    service = OllamaService(service_settings, session=session)
    result = service.generate("Hello")

    assert result["response"] == "Generated text"
    assert result["model"] == "gemma:2b"
    session.post.assert_called_once()
    call_kwargs = session.post.call_args
    assert call_kwargs[1]["json"]["model"] == "gemma:2b"
    assert call_kwargs[1]["json"]["prompt"] == "Hello"
    assert call_kwargs[1]["json"]["stream"] is False


def test_generate_upstream_error(service_settings, session):
    response = MagicMock()
    response.ok = False
    response.status_code = 500
    response.text = "error"
    session.post.return_value = response

    service = OllamaService(service_settings, session=session)
    with pytest.raises(OllamaUpstreamError):
        service.generate("Hello")


def test_generate_connection_error(service_settings, session):
    session.post.side_effect = requests.Timeout("timed out")

    service = OllamaService(service_settings, session=session)
    with pytest.raises(OllamaUnavailableError):
        service.generate("Hello")
