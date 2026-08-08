"""Background serial reader with pattern-wait and command-send.

Generic (pyserial only) — pairs with the firmware's tagged log format
[<millis>][<LEVEL>][<TAG>] message and the `move/type/...` command interface.
"""

from __future__ import annotations

import re
import threading
import time
from collections import deque
from dataclasses import dataclass
from typing import Optional


import serial

# Matches the diag/heartbeat IP line once WiFi lands in Phase 3, e.g. "ip=1.2.3.4"
DIAG_IP = re.compile(r"\bip=([0-9]+\.[0-9]+\.[0-9]+\.[0-9]+)\b")


@dataclass
class LogMatch:
    line: str
    groups: tuple


class SerialHarness:
    def __init__(self, port: str, baud: int = 115200, buffer_lines: int = 1000):
        self.port = port
        self.baud = baud
        self._ser: Optional[serial.Serial] = None
        self._lines: deque[str] = deque(maxlen=buffer_lines)
        self._lock = threading.Lock()
        self._cv = threading.Condition(self._lock)
        self._stop = threading.Event()
        self._thread: Optional[threading.Thread] = None

    def open(self, reset_usb: bool = False) -> None:
        if self._ser and self._ser.is_open:
            return
        self._ser = serial.Serial()
        self._ser.port = self.port
        self._ser.baudrate = self.baud
        self._ser.timeout = 0.2
        # Assert DTR *before* open: the ESP32 core USBCDC only marks the CDC
        # "connected" (and thus emits TX / accepts our commands cleanly) once
        # DTR is high. Without this the host receives nothing.
        self._ser.dtr = True
        self._ser.rts = False
        self._ser.open()
        if reset_usb:
            self._usb_reset()
            time.sleep(0.2)
        # Re-assert DTR (a USB reset toggle may have cleared it) and let the
        # CDC connection settle before the reader/commands start.
        self._ser.dtr = True
        time.sleep(0.3)

    def close(self) -> None:
        self._stop.set()
        if self._thread and self._thread.is_alive():
            self._thread.join(timeout=2.0)
        if self._ser and self._ser.is_open:
            self._ser.close()
        self._ser = None

    def start_reader(self) -> None:
        if self._thread and self._thread.is_alive():
            return
        self._stop.clear()
        self._thread = threading.Thread(target=self._read_loop, daemon=True)
        self._thread.start()

    def _usb_reset(self) -> None:
        if not self._ser:
            return
        self._ser.setDTR(False)
        self._ser.setRTS(True)
        time.sleep(0.1)
        self._ser.setRTS(False)

    def _read_loop(self) -> None:
        assert self._ser is not None
        buf = ""
        while not self._stop.is_set():
            try:
                chunk = self._ser.read(4096)
            except serial.SerialException:
                break
            if not chunk:
                continue
            buf += chunk.decode("utf-8", errors="replace")
            while "\n" in buf:
                line, buf = buf.split("\n", 1)
                line = line.rstrip("\r")
                if not line:
                    continue
                with self._cv:
                    self._lines.append(line)
                    self._cv.notify_all()

    def send_command(self, cmd: str) -> None:
        if not self._ser or not self._ser.is_open:
            raise RuntimeError("serial port not open")
        payload = (cmd.rstrip("\r\n") + "\n").encode("utf-8")
        self._ser.write(payload)
        self._ser.flush()

    def recent_lines(self, n: int = 50) -> list[str]:
        with self._lock:
            return list(self._lines)[-n:]

    def clear_buffer(self) -> None:
        with self._lock:
            self._lines.clear()

    def wait_for_pattern(
        self, pattern: "str | re.Pattern[str]", timeout: float = 10.0
    ) -> LogMatch:
        rx = pattern if isinstance(pattern, re.Pattern) else re.compile(pattern)
        deadline = time.time() + timeout
        with self._cv:
            while time.time() < deadline:
                for line in self._lines:
                    m = rx.search(line)
                    if m:
                        return LogMatch(line=line, groups=m.groups())
                remaining = deadline - time.time()
                if remaining <= 0:
                    break
                self._cv.wait(timeout=min(0.25, remaining))
        recent = "\n".join(self.recent_lines(20))
        raise TimeoutError(
            f"pattern {rx.pattern!r} not seen in {timeout}s\nrecent:\n{recent}"
        )

    def send_and_wait(
        self, cmd: str, pattern: "str | re.Pattern[str]", timeout: float = 10.0
    ) -> LogMatch:
        self.send_command(cmd)
        return self.wait_for_pattern(pattern, timeout=timeout)
