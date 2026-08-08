"""pytest configuration and session fixtures for usb-hid-s3."""

from __future__ import annotations

import os
import subprocess
import sys
from pathlib import Path

import pytest

from tests.config import TestConfig
from tests.harness.serial_harness import SerialHarness

PROJECT_ROOT = Path(__file__).resolve().parent.parent


def pytest_configure(config):
    config.addinivalue_line("markers", "integration: on-device serial command tests")
    config.addinivalue_line("markers", "enumeration: USB/HID enumeration checks (macOS)")
    config.addinivalue_line("markers", "e2e: end-to-end HID action tests (macOS, moves cursor)")
    config.addinivalue_line("markers", "ble: BLE (NUS) control transport tests (needs bleak + RUN_BLE=1)")
    config.addinivalue_line("markers", "wifi: WiFi TCP control transport tests (needs creds + RUN_WIFI=1)")


@pytest.fixture(scope="session")
def test_config() -> TestConfig:
    return TestConfig.load()


@pytest.fixture(scope="session")
def serial_harness(test_config: TestConfig):
    if not test_config.esp_port:
        pytest.skip("ESP_PORT not set and no /dev/cu.usbmodem* found")
    if not os.path.exists(test_config.esp_port):
        pytest.skip(f"serial port not found: {test_config.esp_port}")
    harness = SerialHarness(test_config.esp_port, baud=test_config.serial_baud)
    harness.open(reset_usb=False)
    harness.start_reader()
    yield harness
    harness.close()


@pytest.fixture(scope="session", autouse=True)
def _mouse_warning():
    print(
        "\n*** usb-hid-s3 E2E: the device will move the cursor and type. "
        "Keep hands off the trackpad; focus a scratch window for 'type' tests. ***\n",
        file=sys.stderr,
    )
    yield


@pytest.hookimpl(hookwrapper=True)
def pytest_runtest_makereport(item, call):
    outcome = yield
    report = outcome.get_result()
    if report.when == "call" and report.failed:
        harness = item.funcargs.get("serial_harness")
        if isinstance(harness, SerialHarness):
            print("\n--- last 40 serial lines ---", file=sys.stderr)
            for line in harness.recent_lines(40):
                print(line, file=sys.stderr)


def run_compile() -> None:
    """Compile the firmware via PlatformIO (used by the smoke test)."""
    pio = os.path.expanduser("~/.platformio/penv/bin/pio")
    if not os.path.exists(pio):
        pio = "pio"
    subprocess.run([pio, "run", "-e", "esp32s3"], check=True, cwd=PROJECT_ROOT)
