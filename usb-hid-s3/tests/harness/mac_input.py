"""macOS input observation for E2E: read cursor position and capture HID events.

- Cursor position uses Quartz `CGEventGetLocation` (no special permission needed).
- Keystroke / mouse-move capture uses a `CGEventTap` on a background thread.
  Event taps require the running terminal/Python to have **Input Monitoring**
  (and often **Accessibility**) permission. If the tap can't be created,
  `EventCapture.start()` raises PermissionError so tests can skip cleanly.
"""

from __future__ import annotations

import threading
import time
from typing import Optional

try:
    import Quartz  # type: ignore
    _HAVE_QUARTZ = True
except Exception:  # pragma: no cover - import guard
    _HAVE_QUARTZ = False


def have_quartz() -> bool:
    return _HAVE_QUARTZ


def cursor_position() -> tuple[float, float]:
    """Return the current global cursor position (x, y)."""
    if not _HAVE_QUARTZ:
        raise RuntimeError("Quartz not available; pip install pyobjc-framework-Quartz")
    ev = Quartz.CGEventCreate(None)
    loc = Quartz.CGEventGetLocation(ev)
    return (loc.x, loc.y)


class EventCapture:
    """Capture keyDown and mouseMoved events via a CGEventTap.

    Usage:
        with EventCapture() as cap:
            ... trigger device actions ...
            cap.wait_for_key(timeout=5)
    """

    def __init__(self, capture_keys: bool = True, capture_mouse: bool = True):
        if not _HAVE_QUARTZ:
            raise RuntimeError("Quartz not available")
        self._capture_keys = capture_keys
        self._capture_mouse = capture_mouse
        self._keycodes: list[int] = []
        self._mouse_moves: int = 0
        self._lock = threading.Lock()
        self._cv = threading.Condition(self._lock)
        self._thread: Optional[threading.Thread] = None
        self._runloop = None
        self._tap = None
        self._started = threading.Event()
        self._error: Optional[BaseException] = None

    # -- context manager --
    def __enter__(self) -> "EventCapture":
        self.start()
        return self

    def __exit__(self, *exc) -> None:
        self.stop()

    def _callback(self, proxy, etype, event, refcon):
        if etype == Quartz.kCGEventKeyDown:
            kc = Quartz.CGEventGetIntegerValueField(
                event, Quartz.kCGKeyboardEventKeycode
            )
            with self._cv:
                self._keycodes.append(int(kc))
                self._cv.notify_all()
        elif etype == Quartz.kCGEventMouseMoved:
            with self._cv:
                self._mouse_moves += 1
                self._cv.notify_all()
        return event

    def _run(self):
        mask = 0
        if self._capture_keys:
            mask |= Quartz.CGEventMaskBit(Quartz.kCGEventKeyDown)
        if self._capture_mouse:
            mask |= Quartz.CGEventMaskBit(Quartz.kCGEventMouseMoved)

        tap = Quartz.CGEventTapCreate(
            Quartz.kCGHIDEventTap,
            Quartz.kCGHeadInsertEventTap,
            Quartz.kCGEventTapOptionListenOnly,
            mask,
            self._callback,
            None,
        )
        if not tap:
            self._error = PermissionError(
                "CGEventTapCreate failed - grant Input Monitoring/Accessibility "
                "permission to the terminal running these tests."
            )
            self._started.set()
            return

        self._tap = tap
        src = Quartz.CFMachPortCreateRunLoopSource(None, tap, 0)
        self._runloop = Quartz.CFRunLoopGetCurrent()
        Quartz.CFRunLoopAddSource(self._runloop, src, Quartz.kCFRunLoopDefaultMode)
        Quartz.CGEventTapEnable(tap, True)
        self._started.set()
        Quartz.CFRunLoopRun()

    def start(self) -> None:
        self._thread = threading.Thread(target=self._run, daemon=True)
        self._thread.start()
        self._started.wait(timeout=5.0)
        if self._error:
            raise self._error

    def stop(self) -> None:
        if self._runloop is not None:
            Quartz.CFRunLoopStop(self._runloop)
        if self._thread:
            self._thread.join(timeout=2.0)

    # -- queries --
    def key_count(self) -> int:
        with self._lock:
            return len(self._keycodes)

    def keycodes(self) -> list[int]:
        with self._lock:
            return list(self._keycodes)

    def mouse_move_count(self) -> int:
        with self._lock:
            return self._mouse_moves

    def wait_for_key(self, timeout: float = 5.0) -> bool:
        deadline = time.time() + timeout
        with self._cv:
            while time.time() < deadline:
                if self._keycodes:
                    return True
                self._cv.wait(timeout=min(0.2, max(0.0, deadline - time.time())))
        return False

    def wait_for_mouse_move(self, timeout: float = 5.0) -> bool:
        deadline = time.time() + timeout
        with self._cv:
            while time.time() < deadline:
                if self._mouse_moves > 0:
                    return True
                self._cv.wait(timeout=min(0.2, max(0.0, deadline - time.time())))
        return False
