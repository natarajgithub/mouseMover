"""WiFi TCP control-transport tests.

Drives the device over WiFi like a future networked client would: enable the
radio over serial (`radio wifi`), read back the DHCP IP from the serial log,
then open a TCP connection to the control port and send command lines.
Verification is via the firmware's serial log (commands from WiFi are tagged
`src=wifi`), proving the TCP -> command pipeline reaches the USB-HID layer.

Gated behind RUN_WIFI=1 because it needs WiFi credentials flashed into the
firmware (include/wifi_secrets.h) and the test host on the same LAN as the
device.

Run:
    RUN_WIFI=1 ESP_PORT=$(ls /dev/cu.usbmodem* | head -1) \
        python3 -m pytest tests/e2e/test_wifi_control.py -m wifi -v
"""

from __future__ import annotations

import os
import re
import socket
import time

import pytest

CONTROL_PORT = 3333
IP_RE = re.compile(r"connected ip=([0-9]+\.[0-9]+\.[0-9]+\.[0-9]+)")

pytestmark = pytest.mark.wifi


def _require_wifi():
    if os.environ.get("RUN_WIFI") != "1":
        pytest.skip("WiFi tests are opt-in; set RUN_WIFI=1 to run")


@pytest.fixture(scope="module")
def wifi_ip(serial_harness):
    """Bring up WiFi over serial and return the device's DHCP IP.

    Force a clean transition (radio none -> radio wifi) so the "connected ip="
    line fires even if a previous run left the radio in WiFi mode.
    """
    _require_wifi()
    serial_harness.send_command("radio none")
    time.sleep(0.8)
    serial_harness.clear_buffer()
    try:
        m = serial_harness.send_and_wait("radio wifi", IP_RE, timeout=25.0)
    except TimeoutError:
        pytest.skip("WiFi did not connect (check creds/2.4GHz network in range)")
    ip = m.groups[0]
    assert ip
    time.sleep(0.5)
    yield ip
    try:
        serial_harness.send_command("radio none")
        time.sleep(0.5)
    except Exception:
        pass


def _tcp_send(ip: str, *commands: str) -> None:
    sk = socket.create_connection((ip, CONTROL_PORT), timeout=6)
    try:
        for c in commands:
            sk.sendall((c + "\n").encode())
            time.sleep(0.8)
    finally:
        sk.close()


def test_wifi_connects_and_reports_ip(wifi_ip, serial_harness):
    """`radio wifi` connects and status reports the wifi IP + control port."""
    m = serial_harness.send_and_wait("status", r"radio=wifi:", timeout=5.0)
    assert wifi_ip in m.line


def test_wifi_tcp_command_moves_mouse(wifi_ip, serial_harness):
    """A command over the TCP control port is received (src=wifi) and drives HID."""
    serial_harness.clear_buffer()
    _tcp_send(wifi_ip, "move 41 0")
    m = serial_harness.wait_for_pattern(r'src=wifi line="move 41 0"', timeout=6.0)
    assert "src=wifi" in m.line
    serial_harness.wait_for_pattern(r"move ok dx=41", timeout=3.0)


def test_wifi_tcp_type_command(wifi_ip, serial_harness):
    """A `type` command over TCP reaches the keyboard HID path."""
    serial_harness.clear_buffer()
    _tcp_send(wifi_ip, "type wifi")
    m = serial_harness.wait_for_pattern(r"src=wifi", timeout=6.0)
    assert 'line="type wifi"' in m.line
