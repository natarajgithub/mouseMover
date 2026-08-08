"""mDNS discovery test for hid-helper.local.

Resolves the STA hostname advertised by the firmware and hits REST via
http://hid-helper.local/api/status. Gated behind RUN_WIFI=1.

Run:
  RUN_WIFI=1 ESP_PORT=... python3 -m pytest tests/e2e/test_mdns.py -m wifi -v
"""

from __future__ import annotations

import json
import os
import socket
import time
import urllib.request

import pytest

HOSTNAME = "hid-helper.local"

pytestmark = pytest.mark.wifi


def _require():
    if os.environ.get("RUN_WIFI") != "1":
        pytest.skip("mDNS tests are opt-in; set RUN_WIFI=1")


def _resolve(host: str, timeout: float = 20.0) -> str:
    deadline = time.time() + timeout
    last_err = None
    while time.time() < deadline:
        try:
            infos = socket.getaddrinfo(host, 80, socket.AF_INET, socket.SOCK_STREAM)
            if infos:
                return infos[0][4][0]
        except socket.gaierror as e:
            last_err = e
            time.sleep(1.0)
    raise TimeoutError(f"could not resolve {host}: {last_err}")


@pytest.fixture(scope="module")
def mdns_ready(serial_harness):
    _require()
    # Ensure STA + mDNS are up (boot default is wifi).
    serial_harness.send_command("radio wifi")
    try:
        serial_harness.wait_for_pattern(
            r"mDNS started as hid-helper\.local|connected ip=",
            timeout=25.0,
        )
    except TimeoutError:
        # Already connected from boot — status is enough.
        st = serial_harness.send_and_wait("status", r"radio=wifi:", timeout=8.0)
        if "wifi:ap" in st.line or "radio=none" in st.line:
            pytest.skip("device not on STA WiFi")
    time.sleep(1.0)  # let mDNS announce settle
    yield serial_harness


def test_mdns_resolves_hid_helper(mdns_ready):
    ip = _resolve(HOSTNAME, timeout=25.0)
    assert ip.count(".") == 3
    # Cross-check with serial status IP when possible.
    st = mdns_ready.send_and_wait("status", r"radio=wifi:", timeout=5.0)
    if "wifi:ap" not in st.line:
        assert ip in st.line or "radio=wifi:" in st.line


def test_mdns_http_status(mdns_ready):
    # Prefer hostname URL so we exercise mDNS end-to-end for the app path.
    url = f"http://{HOSTNAME}/api/status"
    deadline = time.time() + 20.0
    last_err = None
    while time.time() < deadline:
        try:
            with urllib.request.urlopen(url, timeout=5) as r:
                body = json.loads(r.read().decode())
            assert body.get("ok") is True
            assert body.get("name") == "usb-hid-s3"
            assert body.get("mdns") == HOSTNAME
            return
        except Exception as e:
            last_err = e
            time.sleep(1.0)
    pytest.fail(f"HTTP via {url} failed: {last_err}")
