import os
import sys

from app import create_app

if os.getenv("FLASK_DEBUG", "").lower() in ("1", "true", "yes"):
    print("Refusing to start: FLASK_DEBUG must not be enabled", file=sys.stderr)
    sys.exit(1)

app = create_app()

if __name__ == "__main__":
    app.run(host="127.0.0.1", port=5000, debug=False)
