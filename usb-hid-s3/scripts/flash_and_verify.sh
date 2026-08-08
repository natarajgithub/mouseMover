#!/usr/bin/env bash
# Flash the firmware (waiting for a manual BOOT+RESET), then capture the serial
# boot banner and run the on-device test suite. One-shot convenience for the
# native-USB S3 which can't auto-reset into the bootloader.
#
# Usage: ./scripts/flash_and_verify.sh [max_wait_tries]

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$PROJECT_DIR"

PIO="${PIO:-$HOME/.platformio/penv/bin/pio}"
command -v "$PIO" >/dev/null 2>&1 || PIO="pio"
PY="${PYTHON:-python3}"
TRIES="${1:-200}"

echo "=== Building ==="
"$PIO" run -e esp32s3 || exit 1

echo ""
echo ">>> Put the board in DOWNLOAD MODE now: hold BOOT, tap RESET, release BOOT."
echo ">>> Waiting to flash..."
FLASHED=0
for i in $(seq 1 "$TRIES"); do
  P=$(ls /dev/cu.usbmodem* 2>/dev/null | head -1)
  if [ -n "$P" ] && "$PIO" run -e esp32s3 -t upload --upload-port "$P" >/tmp/mj_up.log 2>&1; then
    echo "FLASH_OK port=$P"
    FLASHED=1
    break
  fi
  echo "[try $i/$TRIES] waiting for download mode (port=${P:-none})"
  sleep 4
done

if [ "$FLASHED" != "1" ]; then
  echo "FLASH_FAILED: board never entered download mode."
  tail -20 /tmp/mj_up.log 2>/dev/null
  exit 1
fi

echo ""
echo ">>> POWER-CYCLE the board now: unplug and replug the USB cable."
echo ">>> (esptool leaves the S3 in USB-Serial-JTAG mode; a power cycle is"
echo ">>>  required to boot the app into native USB-OTG so it enumerates as HID.)"
echo "=== Waiting for the app to enumerate as VID 0xCAFE ==="
DEVICE_UP=0
for i in $(seq 1 60); do
  if system_profiler SPUSBDataType 2>/dev/null | grep -qi "0xcafe"; then
    DEVICE_UP=1
    break
  fi
  echo "[wait $i/60] app not up yet (power-cycle the cable)"
  sleep 2
done

if [ "$DEVICE_UP" != "1" ]; then
  echo "DEVICE_NOT_UP: 0xCAFE never enumerated after power cycle."
  exit 1
fi
echo "DEVICE_UP (0xCAFE enumerated)"

# CDC port may appear a beat after enumeration; wait for it.
P=""
for i in $(seq 1 20); do
  P=$(ls /dev/cu.usbmodem* 2>/dev/null | head -1)
  [ -n "$P" ] && break
  sleep 0.5
done
echo "port=$P"

echo "=== Serial boot banner ==="
"$PY" - "$P" <<'PY'
import sys, time
try:
    import serial
except Exception as e:
    print("pyserial missing:", e); sys.exit(0)
port = sys.argv[1]
if not port:
    print("no CDC port found"); sys.exit(0)
try:
    s = serial.Serial()
    s.port = port; s.baudrate = 115200; s.timeout = 0.3
    s.dtr = True; s.rts = False   # core USBCDC needs DTR high to emit TX
    s.open()
except Exception as e:
    print("serial open failed:", e); sys.exit(0)
time.sleep(0.5)
s.write(b"version\nstatus\n"); s.flush()
t = time.time()
while time.time() - t < 6:
    d = s.read(4096)
    if d:
        sys.stdout.write(d.decode("utf-8", "replace")); sys.stdout.flush()
s.close()
PY

echo ""
echo "=== Native unit tests ==="
"$PIO" test -e native || true

echo ""
echo "=== Device tests (integration + enumeration) ==="
mkdir -p tests/output
MARKERS="integration or enumeration"
# E2E (cursor/keystroke capture) needs macOS Input Monitoring permission and
# pops a system prompt, so it's opt-in to avoid blocking automation.
if [ "${RUN_E2E:-0}" = "1" ]; then
  MARKERS="integration or enumeration or e2e"
fi
ESP_PORT="$P" "$PY" -m pytest tests/e2e -m "$MARKERS" \
  -v --tb=short --junitxml=tests/output/junit.xml || true

echo "VERIFY_DONE"
