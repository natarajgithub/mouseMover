"""NVS WiFi provisioning + Soft-AP setup tests.

Flow under test:
  1. `wifi clear` forgets STA creds (even if compile-time secrets exist).
  2. `radio wifi` with no creds → Soft-AP `usb-hid-s3-XXXX` + HTTP :80.
  3. `wifi set <ssid> <pass>` over serial → NVS save → STA connect.

Soft-AP REST (`POST /api/wifi`) is exercised when RUN_WIFI_AP_REST=1 and the
host can join the Soft-AP (disruptive to the Mac's current WiFi). Default path
uses serial provisioning only.

Restore STA credentials from env:
  WIFI_TEST_SSID / WIFI_TEST_PASS
or from untracked include/wifi_secrets.h if present.

Run:
  ESP_PORT=... WIFI_TEST_SSID=... WIFI_TEST_PASS=... \\
    python3 -m pytest tests/e2e/test_wifi_provision.py -m wifi -v
"""

from __future__ import annotations

import os
import re
import time
from pathlib import Path

import pytest

PROJECT_ROOT = Path(__file__).resolve().parents[2]
SECRETS = PROJECT_ROOT / "include" / "wifi_secrets.h"
SOFT_AP_PREFIX = "usb-hid-s3-"
SOFT_AP_PATTERN = re.compile(r"^usb-hid-s3-[0-9A-F]{4}$")

pytestmark = pytest.mark.wifi


def _require_wifi_marker_env():
    # Reuse RUN_WIFI gate so this suite stays opt-in like the TCP control tests.
    if os.environ.get("RUN_WIFI") != "1":
        pytest.skip("WiFi provision tests are opt-in; set RUN_WIFI=1")


def _load_restore_creds() -> tuple[str, str]:
    ssid = os.environ.get("WIFI_TEST_SSID", "").strip()
    password = os.environ.get("WIFI_TEST_PASS", "")
    if ssid:
        return ssid, password
    if SECRETS.is_file():
        text = SECRETS.read_text(encoding="utf-8", errors="replace")
        m_ssid = re.search(r'#define\s+WIFI_SSID\s+"([^"]*)"', text)
        m_pass = re.search(r'#define\s+WIFI_PASS\s+"([^"]*)"', text)
        if m_ssid:
            return m_ssid.group(1), (m_pass.group(1) if m_pass else "")
    pytest.skip(
        "Need WIFI_TEST_SSID/WIFI_TEST_PASS or include/wifi_secrets.h to restore STA"
    )


def _parse_soft_ap_ssid(line: str) -> str | None:
    m = re.search(r'soft-ap ssid="([^"]+)"', line)
    if m:
        return m.group(1)
    m = re.search(r"soft-ap ssid=([^\s]+)", line)
    if m:
        return m.group(1)
    return None


@pytest.fixture(scope="module")
def provision(serial_harness):
    _require_wifi_marker_env()
    ssid, password = _load_restore_creds()
    harness = serial_harness
    # Ensure we start from a known radio state.
    harness.send_command("radio none")
    time.sleep(1.0)
    yield harness, ssid, password
    # Always try to restore home WiFi creds + leave radio off.
    try:
        if password:
            harness.send_command(f"wifi set {ssid} {password}")
        else:
            harness.send_command(f"wifi set {ssid}")
        time.sleep(2.0)
        harness.send_command("radio none")
        time.sleep(0.5)
    except Exception:
        pass


def test_wifi_clear_then_soft_ap(provision):
    harness, _ssid, _password = provision
    harness.clear_buffer()
    harness.send_and_wait("wifi clear", r"wifi clear ok|nvs cleared", timeout=5.0)
    harness.clear_buffer()
    m = harness.send_and_wait("radio wifi", r"soft-ap ssid=", timeout=15.0)
    ap_ssid = _parse_soft_ap_ssid(m.line)
    assert ap_ssid is not None
    assert ap_ssid.startswith(SOFT_AP_PREFIX)
    assert SOFT_AP_PATTERN.match(ap_ssid)
    st = harness.send_and_wait("wifi status", r"configured=no", timeout=5.0)
    assert "soft_ap=yes" in st.line
    st2 = harness.send_and_wait("status", r"radio=wifi:ap", timeout=5.0)
    assert "wifi:ap" in st2.line


def test_wifi_set_serial_connects_sta(provision):
    harness, ssid, password = provision
    # Ensure Soft-AP (or at least cleared) first.
    harness.send_command("wifi clear")
    time.sleep(0.5)
    harness.send_command("radio wifi")
    time.sleep(2.0)
    harness.clear_buffer()
    cmd = f"wifi set {ssid} {password}" if password else f"wifi set {ssid}"
    harness.send_command(cmd)
    m = harness.wait_for_pattern(r"connected ip=", timeout=25.0)
    assert "control-port=3333" in m.line
    st = harness.send_and_wait("wifi status", r"configured=yes", timeout=5.0)
    assert f'ssid="{ssid}"' in st.line
    assert "soft_ap=no" in st.line


def _wifi_iface() -> str:
    # Prefer en0; allow override for Macs with multiple radios.
    return os.environ.get("WIFI_IFACE", "en0")


def _join_network(ssid: str, password: str = "") -> None:
    import subprocess

    iface = _wifi_iface()
    if password:
        subprocess.run(
            ["networksetup", "-setairportnetwork", iface, ssid, password],
            check=False,
            capture_output=True,
            text=True,
            timeout=30,
        )
    else:
        subprocess.run(
            ["networksetup", "-setairportnetwork", iface, ssid],
            check=False,
            capture_output=True,
            text=True,
            timeout=30,
        )
    time.sleep(4.0)


def test_soft_ap_rest_configures_wifi(provision):
    """Join Soft-AP, GET/POST /api/wifi, confirm STA connect on serial.

    Gated: RUN_WIFI_AP_REST=1 (temporarily leaves the Mac's home WiFi).
    """
    if os.environ.get("RUN_WIFI_AP_REST") != "1":
        pytest.skip("Set RUN_WIFI_AP_REST=1 to join Soft-AP and hit REST")

    import json
    import urllib.error
    import urllib.request

    harness, ssid, password = provision
    harness.send_command("wifi clear")
    time.sleep(0.5)
    harness.clear_buffer()
    m = harness.send_and_wait("radio wifi", r"soft-ap ssid=", timeout=15.0)
    ap_ssid = _parse_soft_ap_ssid(m.line)
    assert ap_ssid is not None
    assert SOFT_AP_PATTERN.match(ap_ssid)

    _join_network(ap_ssid)
    try:
        with urllib.request.urlopen("http://192.168.4.1/api/wifi", timeout=8) as r:
            body = json.loads(r.read().decode())
        assert body.get("mode") == "ap"
        assert body.get("configured") is False
        assert body.get("ap_ssid") == ap_ssid
        device_id = body.get("device_id", "")
        assert isinstance(device_id, str) and len(device_id) == 12

        payload = json.dumps({"ssid": ssid, "password": password}).encode()
        req = urllib.request.Request(
            "http://192.168.4.1/api/wifi",
            data=payload,
            headers={"Content-Type": "application/json"},
            method="POST",
        )
        with urllib.request.urlopen(req, timeout=8) as r:
            resp = json.loads(r.read().decode())
        assert resp.get("ok") is True
        assert resp.get("reconnecting") is True
    except (urllib.error.URLError, TimeoutError, OSError) as e:
        pytest.fail(f"Soft-AP REST failed (is the Mac on {ap_ssid}?): {e}")
    finally:
        # Restore host WiFi regardless of REST outcome.
        _join_network(ssid, password)

    m = harness.wait_for_pattern(r"connected ip=", timeout=25.0)
    assert "control-port=3333" in m.line
