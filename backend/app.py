from flask import Flask, request, jsonify
from flask_cors import CORS
import requests
import os

app = Flask(__name__)
CORS(app, origins=["*"])  # tighten later if needed

OLLAMA_URL = os.getenv("OLLAMA_URL", "http://localhost:11434")
MODEL = "gemma:2b"

@app.route("/api/health", methods=["GET"])
def health():
    try:
        r = requests.get(f"{OLLAMA_URL}/api/tags", timeout=5)
        return jsonify({
            "status": "healthy",
            "ollama": OLLAMA_URL,
            "model": MODEL,
            "ollama_status": r.status_code
        })
    except Exception as e:
        return jsonify({"status": "degraded", "error": str(e)}), 500

@app.route("/api/chat", methods=["POST"])
def chat():
    data = request.get_json()
    message = data.get("message", "").strip()
    if not message:
        return jsonify({"error": "Message is required"}), 400

    try:
        payload = {
            "model": MODEL,
            "prompt": message,
            "stream": False
        }
        resp = requests.post(f"{OLLAMA_URL}/api/generate", json=payload, timeout=120)
        resp.raise_for_status()
        result = resp.json()
        return jsonify({
            "response": result.get("response", "No response generated."),
            "model": MODEL
        })
    except Exception as e:
        return jsonify({"error": f"Ollama error: {str(e)}"}), 500

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000, debug=False)
