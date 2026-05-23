from __future__ import annotations

import time

import requests
import structlog

from config.settings import Settings
from utils.metrics import record_ollama_generate
from utils.exceptions import (
    ModelNotReadyError,
    OllamaUnavailableError,
    OllamaUpstreamError,
)

logger = structlog.get_logger(__name__)


class OllamaService:
    def __init__(self, settings: Settings, session: requests.Session | None = None):
        self._settings = settings
        self._session = session or requests.Session()

    @property
    def model(self) -> str:
        return self._settings.ollama_model

    @property
    def base_url(self) -> str:
        return self._settings.ollama_url

    def check_ready(self) -> dict:
        """Verify Ollama is reachable and the configured model is available."""
        try:
            response = self._session.get(
                f"{self.base_url}/api/tags",
                timeout=self._settings.ollama_timeout_seconds,
            )
        except requests.RequestException as exc:
            logger.warning("ollama_tags_request_failed", error=str(exc))
            raise OllamaUnavailableError(f"Ollama unreachable: {exc}") from exc

        if not response.ok:
            logger.warning(
                "ollama_tags_bad_status",
                status_code=response.status_code,
            )
            raise OllamaUpstreamError(f"Ollama returned status {response.status_code}")

        data = response.json()
        models = [m.get("name", "") for m in data.get("models", [])]
        model_ready = any(
            name == self.model or name.startswith(f"{self.model}:") for name in models
        )

        if not model_ready:
            raise ModelNotReadyError(
                f"Model '{self.model}' is not available yet. Available models: {models or 'none'}"
            )

        return {
            "status": "ready",
            "ollama": self.base_url,
            "model": self.model,
            "ollama_status": response.status_code,
            "models_available": models,
        }

    def generate(self, prompt: str) -> dict:
        payload = {
            "model": self.model,
            "prompt": prompt,
            "stream": False,
        }

        start = time.perf_counter()
        outcome = "error"
        try:
            response = self._session.post(
                f"{self.base_url}/api/generate",
                json=payload,
                timeout=self._settings.ollama_generate_timeout_seconds,
            )
        except requests.RequestException as exc:
            duration_ms = round((time.perf_counter() - start) * 1000, 2)
            record_ollama_generate(
                self._settings,
                model=self.model,
                outcome="error",
                duration_ms=duration_ms,
            )
            logger.warning(
                "ollama_generate_request_failed",
                error=str(exc),
                duration_ms=duration_ms,
            )
            raise OllamaUnavailableError(f"Ollama unreachable: {exc}") from exc

        duration_ms = round((time.perf_counter() - start) * 1000, 2)

        if not response.ok:
            record_ollama_generate(
                self._settings,
                model=self.model,
                outcome="error",
                duration_ms=duration_ms,
            )
            logger.error(
                "ollama_generate_bad_status",
                status_code=response.status_code,
                body=response.text[:500],
                duration_ms=duration_ms,
            )
            raise OllamaUpstreamError(f"Ollama generate failed with status {response.status_code}")

        outcome = "success"
        result = response.json()
        record_ollama_generate(
            self._settings,
            model=self.model,
            outcome=outcome,
            duration_ms=duration_ms,
        )
        logger.info(
            "ollama_generate_completed",
            model=self.model,
            duration_ms=duration_ms,
            ollama_total_duration_ns=result.get("total_duration"),
            ollama_eval_duration_ns=result.get("eval_duration"),
        )
        return {
            "response": result.get("response", "No response generated."),
            "model": self.model,
        }
