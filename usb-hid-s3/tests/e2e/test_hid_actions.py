"""End-to-end HID action tests on macOS.

Confirms the device actually drives this Mac: the cursor moves on `move`/jiggle,
and keystrokes are received on `type`/`key`. Mouse-move detection uses cursor
position polling (no special permission). Keystroke detection uses a CGEventTap
which needs Input Monitoring/Accessibility permission (tests skip if absent).
"""

import sys
import time

import pytest

from tests.harness import mac_input

pytestmark = pytest.mark.e2e

_darwin = pytest.mark.skipif(sys.platform != "darwin", reason="macOS only")


def _quartz_or_skip():
    if not mac_input.have_quartz():
        pytest.skip("pyobjc-framework-Quartz not installed")


@_darwin
def test_move_moves_cursor(serial_harness):
    _quartz_or_skip()
    before = mac_input.cursor_position()
    # Large, chunked move so it's unambiguous regardless of screen edges.
    serial_harness.send_and_wait("move 120 60", r"\[HID\] move ok", timeout=5)
    time.sleep(0.4)
    after = mac_input.cursor_position()
    moved = abs(after[0] - before[0]) + abs(after[1] - before[1])
    # Move back to be polite.
    serial_harness.send_command("move -120 -60")
    assert moved >= 20, f"cursor did not move: before={before} after={after}"


@_darwin
def test_type_produces_keystrokes(serial_harness):
    _quartz_or_skip()
    try:
        cap = mac_input.EventCapture(capture_keys=True, capture_mouse=False)
        cap.start()
    except PermissionError as exc:
        pytest.skip(str(exc))
    try:
        serial_harness.send_and_wait("type abc", r"\[HID\] type ok", timeout=8)
        assert cap.wait_for_key(timeout=5), "no keystrokes captured for 'type abc'"
        assert cap.key_count() >= 3
    finally:
        cap.stop()


@_darwin
def test_key_enter_produces_keystroke(serial_harness):
    _quartz_or_skip()
    try:
        cap = mac_input.EventCapture(capture_keys=True, capture_mouse=False)
        cap.start()
    except PermissionError as exc:
        pytest.skip(str(exc))
    try:
        serial_harness.send_and_wait("key enter", r"\[HID\] key ok enter", timeout=5)
        assert cap.wait_for_key(timeout=5), "no keystroke captured for 'key enter'"
        # macOS keycode for Return is 36.
        assert 36 in cap.keycodes()
    finally:
        cap.stop()


@_darwin
def test_jiggle_moves_then_stops(serial_harness):
    _quartz_or_skip()
    # Enable -> engine fires immediately, so the cursor should move promptly.
    before = mac_input.cursor_position()
    serial_harness.send_and_wait("jiggle on", r"jiggle=on", timeout=5)
    time.sleep(1.0)
    after = mac_input.cursor_position()
    serial_harness.send_and_wait("jiggle off", r"jiggle=off", timeout=5)
    moved = abs(after[0] - before[0]) + abs(after[1] - before[1])
    assert moved >= 1, f"jiggle produced no movement: before={before} after={after}"
