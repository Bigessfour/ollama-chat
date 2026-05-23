import os

bind = os.getenv("GUNICORN_BIND", "127.0.0.1:5000")
workers = int(os.getenv("GUNICORN_WORKERS", "2"))
threads = int(os.getenv("GUNICORN_THREADS", "4"))
worker_class = "gthread"
timeout = int(os.getenv("GUNICORN_TIMEOUT", "120"))
graceful_timeout = int(os.getenv("GUNICORN_GRACEFUL_TIMEOUT", "30"))
keepalive = int(os.getenv("GUNICORN_KEEPALIVE", "5"))
_app_env = os.getenv("APP_ENV", "development")
accesslog = None if _app_env == "production" else "-"
errorlog = "-"
capture_output = True
preload_app = True
