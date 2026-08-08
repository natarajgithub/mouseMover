"""Integration tests: send serial commands, assert on tagged firmware logs.

Requires the board flashed and connected (serial_harness fixture).
"""

import re

import pytest

pytestmark = pytest.mark.integration


def test_version_matches_source(serial_harness, test_config):
    expected = test_config.firmware_version_from_source()
    m = serial_harness.send_and_wait("version", r"version=([0-9.]+)", timeout=5)
    if expected:
        assert m.groups[0] == expected


def test_help_lists_commands(serial_harness):
    serial_harness.send_command("help")
    serial_harness.wait_for_pattern(r"move <dx> <dy>", timeout=5)


def test_status_reports_fields(serial_harness):
    m = serial_harness.send_and_wait("status", r"status .*jiggle=(on|off)", timeout=5)
    assert m.groups[0] in ("on", "off")


def test_move_command_acked(serial_harness):
    serial_harness.send_and_wait("move 25 0", r"\[HID\] move ok dx=25 dy=0", timeout=5)


def test_move_invalid_reports_error(serial_harness):
    serial_harness.send_and_wait("move 10", r"cmd error:", timeout=5)


def test_click_command_acked(serial_harness):
    serial_harness.send_and_wait("click left", r"\[HID\] click ok", timeout=5)


def test_type_command_acked(serial_harness):
    serial_harness.send_and_wait("type e2e", r"\[HID\] type ok len=3", timeout=8)


def test_key_command_acked(serial_harness):
    serial_harness.send_and_wait("key enter", r"\[HID\] key ok enter", timeout=5)


def test_key_combo_parsed(serial_harness):
    # cmd+space -> modifier 0x08, keycode 0x2c (space)
    serial_harness.send_and_wait(
        "key cmd+space", r"\[CMD\] key cmd\+space mod=0x08 kc=0x2c", timeout=5
    )


def test_jiggle_toggle(serial_harness):
    serial_harness.send_and_wait("jiggle on", r"jiggle=on", timeout=5)
    serial_harness.send_and_wait("jiggle status", r"jiggle=on", timeout=5)
    serial_harness.send_and_wait("jiggle off", r"jiggle=off", timeout=5)


def test_unknown_command(serial_harness):
    serial_harness.send_and_wait("frobnicate", r"cmd error:.*frobnicate", timeout=5)
