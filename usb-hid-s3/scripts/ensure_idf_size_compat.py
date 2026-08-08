# Pin esp-idf-size 1.x: PlatformIO espressif32 calls `esp_idf_size --ng`, removed in 2.0+
Import("env")

import subprocess
import sys


def _ensure_compat_idf_size():
    probe = subprocess.run(
        [sys.executable, "-m", "esp_idf_size", "--ng", "-h"],
        capture_output=True,
    )
    if probe.returncode == 0:
        return
    subprocess.run(
        [
            sys.executable,
            "-m",
            "pip",
            "install",
            "esp-idf-size>=1.7.1,<2.0.0",
            "-q",
        ],
        check=False,
    )


_ensure_compat_idf_size()
