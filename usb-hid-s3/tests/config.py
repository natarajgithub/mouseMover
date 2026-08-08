"""Load test configuration from config.env / config.env.example / environment."""

from __future__ import annotations

import glob
import os
from dataclasses import dataclass
from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parent.parent


def _parse_env_file(path: Path) -> dict[str, str]:
    out: dict[str, str] = {}
    if not path.is_file():
        return out
    for line in path.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, _, val = line.partition("=")
        out[key.strip()] = val.strip()
    return out


@dataclass
class TestConfig:
    __test__ = False  # not a pytest test class

    esp_port: str = ""
    serial_baud: int = 115200
    usb_vid: int = 0xCAFE
    usb_pid: int = 0x4001
    usb_product: str = "S3 Mouse+Keyboard"

    @classmethod
    def load(cls) -> "TestConfig":
        file_vals = _parse_env_file(PROJECT_ROOT / "config.env")
        example_vals = _parse_env_file(PROJECT_ROOT / "config.env.example")

        def get(key: str, default: str = "") -> str:
            return os.environ.get(key, file_vals.get(key, example_vals.get(key, default)))

        port = get("ESP_PORT")
        if not port or not os.path.exists(port):
            matches = sorted(glob.glob("/dev/cu.usbmodem*"))
            if matches:
                port = matches[0]

        return cls(
            esp_port=port,
            serial_baud=int(get("SERIAL_BAUD", "115200")),
            usb_vid=int(get("USB_VID", "0xCAFE"), 0),
            usb_pid=int(get("USB_PID", "0x4001"), 0),
            usb_product=get("USB_PRODUCT", "S3 Mouse+Keyboard"),
        )

    @property
    def project_root(self) -> Path:
        return PROJECT_ROOT

    def firmware_version_from_source(self) -> str:
        cfg = PROJECT_ROOT / "include" / "Config.h"
        if not cfg.is_file():
            return ""
        for line in cfg.read_text(encoding="utf-8").splitlines():
            if "FW_VERSION" in line and "#define" in line:
                parts = line.split('"')
                if len(parts) >= 2:
                    return parts[1]
        return ""
