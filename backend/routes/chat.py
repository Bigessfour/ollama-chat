from flask import Blueprint, current_app, jsonify, request
from pydantic import BaseModel, Field, ValidationError as PydanticValidationError

from app.extensions import limiter
from utils.exceptions import ValidationError
from utils.security import require_api_key, require_json_content_type

chat_bp = Blueprint("chat", __name__)


class ChatRequest(BaseModel):
    message: str = Field(..., min_length=1, max_length=8000)


@chat_bp.post("/chat")
@require_api_key
@limiter.limit(lambda: current_app.config["SETTINGS"].rate_limit_chat)
def chat():
    require_json_content_type()

    raw = request.get_data(cache=True)
    if not raw:
        raise ValidationError("Request body is required")

    try:
        body = request.get_json(force=True)
    except Exception as exc:
        raise ValidationError("Invalid JSON body") from exc

    if body is None:
        raise ValidationError("Invalid JSON body")

    try:
        chat_request = ChatRequest.model_validate(body)
    except PydanticValidationError as exc:
        errors = exc.errors()
        first = errors[0] if errors else {}
        msg = first.get("msg", "Invalid request")
        if first.get("loc"):
            loc = ".".join(str(part) for part in first["loc"])
            msg = f"{loc}: {msg}"
        raise ValidationError(msg) from exc

    ollama = current_app.config["OLLAMA_SERVICE"]
    result = ollama.generate(chat_request.message.strip())
    return jsonify(result)
