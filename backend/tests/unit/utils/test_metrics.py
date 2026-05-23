import json
from io import StringIO
from unittest.mock import patch

from config.settings import Settings
from utils.metrics import emit_emf, is_probe_path, record_http_request


def test_is_probe_path():
    assert is_probe_path("/live")
    assert is_probe_path("/api/ready")
    assert not is_probe_path("/api/chat")


def test_emit_emf_disabled():
    settings = Settings(metrics_enabled=False)
    with patch("sys.stdout", new_callable=StringIO) as stdout:
        emit_emf(
            settings,
            metric_defs=[{"Name": "HttpRequestCount", "Unit": "Count"}],
            dimensions={"Service": "test"},
            values={"HttpRequestCount": 1},
        )
        assert stdout.getvalue() == ""


def test_emit_emf_writes_json():
    settings = Settings(metrics_enabled=True, metrics_namespace="TestNS")
    with patch("sys.stdout", new_callable=StringIO) as stdout:
        record_http_request(
            settings,
            method="POST",
            route="chat.chat",
            status_code=200,
            duration_ms=12.5,
        )
        line = stdout.getvalue().strip()
        doc = json.loads(line)
        assert doc["_aws"]["CloudWatchMetrics"][0]["Namespace"] == "TestNS"
        assert doc["HttpRequestCount"] == 1
        assert doc["HttpRequestLatencyMs"] == 12.5
        assert doc["Method"] == "POST"
