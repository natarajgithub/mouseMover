"""BLE (Nordic UART Service) control-transport tests.

Drives the device over BLE like an iOS app would: enable the radio over serial
(`radio ble`), then use a BLE central (bleak) to connect to the NUS RX
characteristic and write command lines. Verification is via the firmware's serial
log (commands from BLE are tagged `src=ble`), proving the BLE -> NUS -> command
pipeline works and reaches the USB-HID layer.

Gated behind RUN_BLE=1 because it needs the `bleak` package and macOS Bluetooth
permission for the process running pytest, and BLE scans are slow.

Run:
    RUN_BLE=1 ESP_PORT=$(ls /dev/cu.usbmodem* | head -1) \
        python3 -m pytest tests/e2e/test_ble_control.py -m ble -v
"""

from __future__ import annotations

import asyncio
import os
import time

import pytest

NUS_SVC = "6e400001-b5a3-f393-e0a9-e50e24dcca9e"
NUS_RX = "6e400002-b5a3-f393-e0a9-e50e24dcca9e"  # host -> device (write)
DEVICE_NAME = "usb-hid-s3"

pytestmark = pytest.mark.ble


def _require_ble():
    if os.environ.get("RUN_BLE") != "1":
        pytest.skip("BLE tests are opt-in; set RUN_BLE=1 to run")
    try:
        import bleak  # noqa: F401
    except Exception:  # pragma: no cover
        pytest.skip("bleak not installed (pip install bleak)")


async def _find_device(timeout: float = 10.0):
    from bleak import BleakScanner

    devs = await BleakScanner.discover(timeout=timeout, return_adv=True)
    for _addr, (dev, adv) in devs.items():
        uuids = [u.lower() for u in (adv.service_uuids or [])]
        name = adv.local_name or dev.name or ""
        if NUS_SVC in uuids or DEVICE_NAME in name:
            return dev
    return None


async def _send_over_ble(command: str) -> None:
    from bleak import BleakClient

    dev = await _find_device()
    assert dev is not None, f"BLE device advertising {NUS_SVC} / '{DEVICE_NAME}' not found"
    async with BleakClient(dev) as client:
        assert client.is_connected
        await asyncio.sleep(0.4)
        await client.write_gatt_char(NUS_RX, (command + "\n").encode(), response=False)
        await asyncio.sleep(0.8)


@pytest.fixture(scope="module")
def ble_enabled(serial_harness):
    """Switch the device to BLE mode over serial; restore `none` afterwards.

    Force a clean none->ble transition so the "advertising" log fires even if a
    previous run left the radio in BLE mode (setMode is a no-op when unchanged).
    """
    _require_ble()
    serial_harness.send_command("radio none")
    time.sleep(0.8)
    m = serial_harness.send_and_wait(
        "radio ble", r"advertising as '" + DEVICE_NAME + r"'", timeout=8.0
    )
    assert DEVICE_NAME in m.line
    time.sleep(0.5)  # let advertising settle before scanning
    yield serial_harness
    try:
        serial_harness.send_command("radio none")
        time.sleep(0.5)
    except Exception:
        pass


def test_ble_advertises(ble_enabled):
    """`radio ble` brings up NUS advertising and status reports ble."""
    m = ble_enabled.send_and_wait("status", r"radio=ble", timeout=5.0)
    assert "radio=ble" in m.line


def test_ble_command_moves_mouse(ble_enabled):
    """A command written over BLE is received (src=ble) and drives the HID mouse."""
    ble_enabled.clear_buffer()
    asyncio.run(_send_over_ble("move 33 0"))
    m = ble_enabled.wait_for_pattern(r'src=ble line="move 33 0"', timeout=6.0)
    assert "src=ble" in m.line
    ble_enabled.wait_for_pattern(r"move ok dx=33", timeout=3.0)


def test_ble_type_command(ble_enabled):
    """A `type` command over BLE reaches the keyboard HID path."""
    ble_enabled.clear_buffer()
    asyncio.run(_send_over_ble("type hi"))
    m = ble_enabled.wait_for_pattern(r"src=ble", timeout=6.0)
    assert 'line="type hi"' in m.line
