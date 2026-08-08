"""USB/HID enumeration tests (macOS): verify the composite mouse+keyboard device."""

import sys

import pytest

from tests.harness import mac_hid

pytestmark = pytest.mark.enumeration

_darwin = pytest.mark.skipif(sys.platform != "darwin", reason="macOS only")


@_darwin
def test_usb_device_enumerates(test_config):
    info = mac_hid.find_usb_device(
        test_config.usb_vid, test_config.usb_pid, test_config.usb_product
    )
    assert info.found, (
        f"USB device VID=0x{test_config.usb_vid:04x} PID=0x{test_config.usb_pid:04x} "
        f"('{test_config.usb_product}') not found in system_profiler"
    )


@_darwin
def test_hid_has_mouse_and_keyboard(test_config):
    usages = mac_hid.hid_usages_for_product(test_config.usb_product)
    if not usages.pairs:
        pytest.skip(
            "No HID usages found for product; device may report a different "
            "product string. Check `ioreg -r -c IOHIDDevice -l`."
        )
    assert usages.has_keyboard, f"keyboard usage (1,6) not present: {usages.pairs}"
    assert usages.has_mouse, f"mouse usage (1,2) not present: {usages.pairs}"
