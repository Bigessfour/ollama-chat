from functools import lru_cache
from typing import Literal

from pydantic import Field, field_validator, model_validator
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        extra="ignore",
        populate_by_name=True,
    )

    app_name: str = "ollama-chat-api"
    app_env: Literal["development", "production"] = Field(default="development", alias="APP_ENV")
    ollama_url: str = Field(default="http://localhost:11434", alias="OLLAMA_URL")
    ollama_model: str = Field(default="gemma:2b", alias="OLLAMA_MODEL")
    log_level: str = Field(default="INFO", alias="LOG_LEVEL")
    log_format: str = Field(default="json", alias="LOG_FORMAT")
    app_version: str = Field(default="dev", alias="APP_VERSION")
    metrics_enabled: bool | None = Field(default=None, alias="METRICS_ENABLED")
    metrics_namespace: str = Field(default="OllamaChat", alias="METRICS_NAMESPACE")
    otel_enabled: bool = Field(default=False, alias="OTEL_ENABLED")
    otel_service_name: str = Field(default="ollama-chat-api", alias="OTEL_SERVICE_NAME")
    otel_exporter: Literal["console", "otlp"] = Field(default="console", alias="OTEL_EXPORTER")
    otel_exporter_otlp_endpoint: str | None = Field(
        default=None, alias="OTEL_EXPORTER_OTLP_ENDPOINT"
    )
    cors_origins: str = Field(default="*", alias="CORS_ORIGINS")
    rate_limit_default: str = Field(default="60 per minute", alias="RATE_LIMIT_DEFAULT")
    rate_limit_chat: str = Field(default="20 per minute", alias="RATE_LIMIT_CHAT")
    rate_limit_ready: str = Field(default="120 per minute", alias="RATE_LIMIT_READY")
    ollama_timeout_seconds: int = Field(default=5, alias="OLLAMA_TIMEOUT_SECONDS")
    ollama_generate_timeout_seconds: int = Field(
        default=120, alias="OLLAMA_GENERATE_TIMEOUT_SECONDS"
    )
    trust_proxy_count: int = Field(default=1, alias="TRUST_PROXY_COUNT")
    max_content_length: int = Field(default=65536, alias="MAX_CONTENT_LENGTH")
    api_key: str | None = Field(default=None, alias="API_KEY")
    require_api_key_in_production: bool = Field(
        default=False, alias="REQUIRE_API_KEY_IN_PRODUCTION"
    )

    @field_validator("ollama_url")
    @classmethod
    def strip_trailing_slash(cls, value: str) -> str:
        return value.rstrip("/")

    @field_validator("api_key")
    @classmethod
    def empty_api_key_to_none(cls, value: str | None) -> str | None:
        if value is None or not str(value).strip():
            return None
        return str(value).strip()

    @field_validator("cors_origins")
    @classmethod
    def validate_cors_origins_format(cls, value: str) -> str:
        stripped = value.strip()
        if stripped == "*":
            return value
        for origin in stripped.split(","):
            origin = origin.strip()
            if not origin:
                continue
            if not origin.startswith(("http://", "https://")):
                raise ValueError(
                    f"CORS origin must start with http:// or https://, got: {origin!r}"
                )
        return value

    @model_validator(mode="after")
    def apply_defaults(self) -> "Settings":
        if self.metrics_enabled is None:
            self.metrics_enabled = self.app_env == "production"
        return self

    @model_validator(mode="after")
    def validate_production_settings(self) -> "Settings":
        if self.app_env == "production" and self.cors_origins.strip() == "*":
            raise ValueError(
                "CORS_ORIGINS must not be '*' when APP_ENV=production. "
                "Set CORS_ORIGINS to your ALB origin, e.g. http://my-alb.us-east-1.elb.amazonaws.com"
            )
        if (
            self.app_env == "production"
            and self.require_api_key_in_production
            and self.api_key is None
        ):
            raise ValueError(
                "API_KEY is required when APP_ENV=production and REQUIRE_API_KEY_IN_PRODUCTION=true"
            )
        return self

    @property
    def cors_origins_list(self) -> list[str]:
        if self.cors_origins.strip() == "*":
            return ["*"]
        return [origin.strip() for origin in self.cors_origins.split(",") if origin.strip()]

    @property
    def is_production(self) -> bool:
        return self.app_env == "production"


@lru_cache
def get_settings() -> Settings:
    return Settings()
