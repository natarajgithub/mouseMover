#!/usr/bin/env bash
# Interactive USB-CDC serial monitor (streams logs + sends commands).
#
# Usage:
#   ./scripts/serial_monitor.sh [PORT]                 Interactive monitor
#   ./scripts/serial_monitor.sh -c "move 30 0" [PORT]  Send one command, print reply, exit
#   ./scripts/serial_monitor.sh --no-reset [PORT]      Do not toggle DTR/RTS on open
#
# Firmware commands (see CommandParser / serviceSerialCommands):
#   move <dx> <dy> [wheel]   Move mouse (relative)
#   click [left|right|middle]
#   type <text>              Type a string via keyboard HID
#   key <name>               Press a named key (enter,esc,tab,up,down,left,right,space,cmd+space,...)
#   jiggle on|off|status     Enable/disable/report constant jiggle
#   radio wifi|ble|none      Select active radio (Phase 3)
#   status | version | help

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
if [[ -f "$PROJECT_DIR/config.env" ]]; then
  ESP_PORT="${ESP_PORT:-$(grep '^ESP_PORT=' "$PROJECT_DIR/config.env" | cut -d= -f2- | tr -d '\r\n')}"
fi

BAUD="${BAUD:-115200}"
PORT=""
SEND_CMD=""
NO_RESET=0

usage() {
  cat <<'EOF'
Usage: ./scripts/serial_monitor.sh [options] [PORT]

Options:
  -c, --cmd CMD    Send one line to the board and exit (e.g. -c "move 30 0")
  --no-reset       Skip USB reset on connect
  -h, --help       Show this help

Interactive commands (type a line + Enter while logs stream):
  move <dx> <dy> [wheel] | click [left|right|middle] | type <text> | key <name>
  jiggle on|off|status | radio wifi|ble|none | status | version | help
  quit, exit       Close monitor
  :reset           USB reset (local, not sent to board)

If PORT is omitted, uses ESP_PORT from config.env or the first /dev/cu.usbmodem*.
Requires pyserial: pip install pyserial
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -c|--cmd) SEND_CMD="${2:-}"; shift 2 ;;
    --no-reset) NO_RESET=1; shift ;;
    -h|--help) usage; exit 0 ;;
    -*) printf 'Unknown option: %s\n' "$1" >&2; usage >&2; exit 1 ;;
    *) PORT="$1"; shift ;;
  esac
done

[[ -z "$PORT" ]] && PORT="${ESP_PORT:-}"

if [[ -z "$PORT" || ! -e "$PORT" ]]; then
  DETECTED="$(ls /dev/cu.usbmodem* 2>/dev/null | head -1)"
  if [[ -n "$DETECTED" && -e "$DETECTED" ]]; then
    echo "Using detected port: $DETECTED"
    PORT="$DETECTED"
  fi
fi

if [[ -z "$PORT" || ! -e "$PORT" ]]; then
  printf 'Error: serial port not found.\n' >&2
  printf 'Connect the board via USB, then run: ls /dev/cu.usb*\n' >&2
  exit 1
fi

if ! python3 -c "import serial" 2>/dev/null; then
  echo "Error: pyserial required. Install: pip install pyserial" >&2
  exit 1
fi

export SM_PORT="$PORT"
export SM_BAUD="$BAUD"
export SM_SEND_CMD="$SEND_CMD"
export SM_NO_RESET="$NO_RESET"

exec python3 - <<'PY'
import os
import sys
import threading
import time

import serial

port = os.environ["SM_PORT"]
baud = int(os.environ["SM_BAUD"])
send_cmd = os.environ.get("SM_SEND_CMD", "")
no_reset = os.environ.get("SM_NO_RESET", "0") == "1"


def usb_reset(ser):
    # NOTE: on the native USB-OTG S3 this does NOT reset the MCU (there's no
    # auto-reset circuit on the OTG port). It only toggles the CDC control
    # lines, so we must re-assert DTR afterwards or the core USBCDC goes
    # "disconnected" and silently drops both TX and RX.
    ser.setDTR(False)
    ser.setRTS(True)
    time.sleep(0.1)
    ser.setRTS(False)
    ser.setDTR(True)  # re-assert: core USBCDC needs DTR high to talk
    time.sleep(0.2)


def send_line(ser, line):
    ser.write((line.rstrip("\r\n") + "\n").encode("utf-8"))
    ser.flush()


def handle_local(ser, line, write_out):
    cmd = line.strip().lower()
    if cmd == ":reset":
        usb_reset(ser)
        write_out("\n(board reset via USB)\n\n")
        return True
    return False


def run_interactive(ser):
    stop = threading.Event()
    lock = threading.Lock()

    def write_out(text):
        with lock:
            sys.stdout.write(text)
            sys.stdout.flush()

    def stdin_loop():
        while not stop.is_set():
            try:
                line = sys.stdin.readline()
            except (EOFError, KeyboardInterrupt):
                break
            if not line or stop.is_set():
                break
            s = line.strip()
            if not s:
                continue
            if s.lower() in ("quit", "exit", "q"):
                stop.set()
                break
            if handle_local(ser, s, write_out):
                continue
            send_line(ser, s)

    threading.Thread(target=stdin_loop, daemon=True).start()
    write_out(f"=== Serial monitor: {port} @ {baud} baud ===\n")
    write_out("Type a command + Enter (e.g. 'move 30 0', 'type hello', 'jiggle on'). Ctrl+C to stop.\n\n")
    try:
        while not stop.is_set():
            try:
                data = ser.read(4096)
            except serial.SerialException:
                break
            if data:
                write_out(data.decode("utf-8", errors="replace"))
    except KeyboardInterrupt:
        write_out("\n(interrupted)\n")
    finally:
        stop.set()


def run_one_shot(ser, cmd):
    send_line(ser, cmd)
    deadline = time.time() + 3.0
    got_any = False
    while time.time() < deadline:
        try:
            data = ser.read(4096)
        except serial.SerialException:
            sys.stderr.write("\n(serial dropped mid-read; device may have reset)\n")
            return
        if data:
            got_any = True
            sys.stdout.write(data.decode("utf-8", errors="replace"))
            sys.stdout.flush()
        else:
            time.sleep(0.05)
    if not got_any:
        sys.stderr.write(
            "\n(no response in 3s: the command may not have been received.\n"
            " The USB-CDC can wedge after repeated reconnects; tap RESET or\n"
            " unplug/replug the board, then retry.)\n"
        )


def main():
    # Build the port WITHOUT opening so we can assert DTR *before* open: the
    # core ESP32 USBCDC only marks the CDC "connected" (accepting our commands
    # and emitting TX) once DTR is high. Without this, nothing is sent/received.
    ser = serial.Serial()
    ser.port = port
    ser.baudrate = baud
    ser.timeout = 0.2
    ser.dtr = True
    ser.rts = False
    ser.open()
    try:
        # The DTR/RTS "reset" only matters on boards with an auto-reset circuit;
        # the native USB-OTG S3 has none, and toggling it just drops the CDC
        # link. So it's now opt-in via SM_RESET=1; the default just settles.
        if not no_reset and os.environ.get("SM_RESET", "0") == "1":
            usb_reset(ser)
        else:
            ser.dtr = True
            time.sleep(0.3)
        if send_cmd:
            run_one_shot(ser, send_cmd)
        else:
            run_interactive(ser)
    finally:
        ser.close()


if __name__ == "__main__":
    main()
PY
