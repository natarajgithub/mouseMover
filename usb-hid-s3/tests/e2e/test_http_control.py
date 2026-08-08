"""STA HTTP REST control API tests.

Requires the device on WiFi (radio wifi / boot default) with a reachable STA IP.
Gated behind RUN_WIFI=1.

Endpoints:
  GET  /api/status
  GET  /api/jiggle
  POST /api/jiggle  {"enabled": true|false}
  POST /api/move    {"dx","dy"}
  POST /api/type    {"text"}
  POST /api/key     {"key"}
  POST /api/click   {"button"}

Run:
  RUN_WIFI=1 ESP_PORT=... python3 -m pytest tests/e2e/test_http_control.py -m wifi -v
"""

from __future__ import annotations

import json
import os
import re
import time
import urllib.error
import urllib.request

import pytest

from Quartz import CGEventCreate, CGEventGetLocation

pytestmark = pytest.mark.wifi


def _require():
    if os.environ.get("RUN_WIFI") != "1":
        pytest.skip("HTTP control tests are opt-in; set RUN_WIFI=1")


def _pos():
    p = CGEventGetLocation(CGEventCreate(None))
    return (p.x, p.y)


def _http(method: str, url: str, body: dict | None = None, timeout: float = 8.0):
    data = None
    headers = {}
    if body is not None:
        data = json.dumps(body).encode()
        headers["Content-Type"] = "application/json"
    req = urllib.request.Request(url, data=data, headers=headers, method=method)
    with urllib.request.urlopen(req, timeout=timeout) as r:
        raw = r.read().decode()
        return r.status, json.loads(raw) if raw else {}


@pytest.fixture(scope="module")
def base_url(serial_harness):
    _require()
    # Ensure WiFi is up (boot default is wifi, but be explicit).
    serial_harness.send_command("radio wifi")
    m = serial_harness.wait_for_pattern(
        r"connected ip=([0-9.]+)|radio=wifi:([0-9.]+)|HTTP REST listening",
        timeout=25.0,
    )
    ip = None
    # Prefer status line
    serial_harness.clear_buffer()
    st = serial_harness.send_and_wait("status", r"radio=wifi:", timeout=8.0)
    mm = re.search(r"radio=wifi:([0-9.]+)", st.line)
    if mm:
        ip = mm.group(1)
    if not ip or ip == "ap":
        pytest.skip("device not on STA WiFi (need configured creds)")
    # Give HTTP server a beat if it just started
    time.sleep(0.5)
    yield f"http://{ip}"
    try:
        _http("POST", f"http://{ip}/api/jiggle", {"enabled": False})
    except Exception:
        pass


def test_http_status(base_url):
    code, body = _http("GET", f"{base_url}/api/status")
    assert code == 200
    assert body.get("ok") is True
    assert body.get("name") == "usb-hid-s3"
    assert body.get("version")
    assert "jiggle" in body


def test_http_jiggle_toggle(base_url, serial_harness):
    serial_harness.clear_buffer()
    code, body = _http("POST", f"{base_url}/api/jiggle", {"enabled": True})
    assert code == 200 and body.get("ok") is True and body.get("enabled") is True
    serial_harness.wait_for_pattern(r'src=http.*jiggle on|jiggle=on', timeout=5.0)
    code, body = _http("GET", f"{base_url}/api/jiggle")
    assert body.get("enabled") is True
    code, body = _http("POST", f"{base_url}/api/jiggle", {"enabled": False})
    assert body.get("enabled") is False
    serial_harness.wait_for_pattern(r"jiggle=off", timeout=5.0)


def test_http_move_cursor(base_url, serial_harness):
    p0 = _pos()
    serial_harness.clear_buffer()
    code, body = _http("POST", f"{base_url}/api/move", {"dx": 100, "dy": 0})
    assert code == 200 and body.get("ok") is True
    serial_harness.wait_for_pattern(r"move ok dx=100", timeout=5.0)
    time.sleep(0.3)
    p1 = _pos()
    assert abs(p1[0] - p0[0]) > 20, f"cursor did not move: {p0} -> {p1}"
    _http("POST", f"{base_url}/api/move", {"dx": -100, "dy": 0})


def test_http_type(base_url, serial_harness):
    serial_harness.clear_buffer()
    code, body = _http("POST", f"{base_url}/api/type", {"text": "rest"})
    assert code == 200 and body.get("ok") is True
    serial_harness.wait_for_pattern(r'src=http.*type rest|type ok len=4', timeout=5.0)


def test_http_key_and_click(base_url, serial_harness):
    serial_harness.clear_buffer()
    code, body = _http("POST", f"{base_url}/api/key", {"key": "enter"})
    assert code == 200 and body.get("ok") is True
    serial_harness.wait_for_pattern(r"key ok enter|src=http", timeout=5.0)
    code, body = _http("POST", f"{base_url}/api/click", {"button": "left"})
    assert code == 200 and body.get("ok") is True
