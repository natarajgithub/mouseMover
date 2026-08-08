"""macOS USB/HID enumeration helpers (system_profiler / ioreg / hidutil)."""

from __future__ import annotations

import json
import subprocess
from dataclasses import dataclass, field


def _run(cmd: list[str], timeout: float = 15.0) -> str:
    try:
        return subprocess.run(
            cmd, capture_output=True, text=True, timeout=timeout
        ).stdout
    except (subprocess.SubprocessError, FileNotFoundError):
        return ""


@dataclass
class UsbDeviceInfo:
    found: bool = False
    name: str = ""
    vendor_id: int = 0
    product_id: int = 0
    manufacturer: str = ""


def _iter_usb_items(node):
    if isinstance(node, dict):
        yield node
        for v in node.values():
            yield from _iter_usb_items(v)
    elif isinstance(node, list):
        for v in node:
            yield from _iter_usb_items(v)


def _parse_hex_id(value) -> int:
    # system_profiler renders ids like "0xcafe" or "0xcafe (something)".
    if value is None:
        return 0
    s = str(value).strip().split()[0]
    try:
        return int(s, 16) if s.lower().startswith("0x") else int(s)
    except ValueError:
        return 0


def find_usb_device(vid: int, pid: int, product: str = "") -> UsbDeviceInfo:
    """Look up a USB device by VID/PID (and optionally product name)."""
    out = _run(["system_profiler", "SPUSBDataType", "-json"])
    if not out:
        return UsbDeviceInfo()
    try:
        data = json.loads(out)
    except json.JSONDecodeError:
        return UsbDeviceInfo()

    for item in _iter_usb_items(data):
        if not isinstance(item, dict):
            continue
        if "vendor_id" not in item and "product_id" not in item:
            continue
        v = _parse_hex_id(item.get("vendor_id"))
        p = _parse_hex_id(item.get("product_id"))
        name = item.get("_name", "")
        if v == vid and p == pid:
            return UsbDeviceInfo(
                found=True,
                name=name,
                vendor_id=v,
                product_id=p,
                manufacturer=item.get("manufacturer", ""),
            )
        if product and product.lower() in str(name).lower():
            return UsbDeviceInfo(
                found=True, name=name, vendor_id=v, product_id=p,
                manufacturer=item.get("manufacturer", ""),
            )
    return UsbDeviceInfo()


@dataclass
class HidUsages:
    # (usage_page, usage) pairs seen for this device's HID interfaces.
    pairs: list[tuple[int, int]] = field(default_factory=list)

    @property
    def has_keyboard(self) -> bool:
        # Generic Desktop (0x01) / Keyboard (0x06)
        return (1, 6) in self.pairs

    @property
    def has_mouse(self) -> bool:
        # Generic Desktop (0x01) / Mouse (0x02)
        return (1, 2) in self.pairs


def hid_usages_for_product(product: str) -> HidUsages:
    """Parse `ioreg -r -c IOHIDDevice -l` for the device's HID usage pairs.

    Matches the block whose Product string contains `product`.
    """
    out = _run(["ioreg", "-r", "-c", "IOHIDDevice", "-l"])
    usages = HidUsages()
    if not out:
        return usages

    # ioreg groups devices with "+-o <name> ..." then indented properties.
    blocks: list[str] = []
    cur: list[str] = []
    for line in out.splitlines():
        if "+-o " in line and cur:
            blocks.append("\n".join(cur))
            cur = [line]
        else:
            cur.append(line)
    if cur:
        blocks.append("\n".join(cur))

    def _num(block: str, key: str) -> int | None:
        import re
        m = re.search(rf'"{key}"\s*=\s*(\d+)', block)
        return int(m.group(1)) if m else None

    for block in blocks:
        if product.lower() not in block.lower():
            continue
        up = _num(block, "PrimaryUsagePage")
        us = _num(block, "PrimaryUsage")
        if up is not None and us is not None:
            usages.pairs.append((up, us))
        # DeviceUsagePairs array (composite) — capture all pairs too.
        import re
        for m in re.finditer(
            r'"DeviceUsagePage"\s*=\s*(\d+).{0,40}?"DeviceUsage"\s*=\s*(\d+)',
            block,
            re.DOTALL,
        ):
            usages.pairs.append((int(m.group(1)), int(m.group(2))))

    # de-dup
    usages.pairs = sorted(set(usages.pairs))
    return usages


def hidutil_list_raw() -> str:
    return _run(["hidutil", "list"])
