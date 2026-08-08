#!/usr/bin/env bash
# usb-hid-s3 - build and USB upload via PlatformIO, with retry.
#
# Usage:
#   ./scripts/deploy.sh [PORT]        Build + upload (auto-detect port if omitted)
#   ESP_PORT=/dev/cu.usbmodemXXXX ./scripts/deploy.sh
#   BUILD_ONLY=1 ./scripts/deploy.sh  Compile only, no upload
#
# The ESP32-S3 runs in native USB-OTG mode, so auto-reset into the bootloader
# often fails. If upload stalls, hold BOOT, tap RESET, release BOOT; the loop
# below retries every 5 s.

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
ENV_NAME="${ENV_NAME:-esp32s3}"

if [[ -f "$PROJECT_DIR/config.env" ]]; then
  ESP_PORT="${ESP_PORT:-$(grep '^ESP_PORT=' "$PROJECT_DIR/config.env" | cut -d= -f2- | tr -d '\r\n')}"
fi

PIO="${PIO:-$HOME/.platformio/penv/bin/pio}"
command -v "$PIO" >/dev/null 2>&1 || PIO="pio"

PORT="${1:-${ESP_PORT:-}}"
if [[ -z "$PORT" || ! -e "$PORT" ]]; then
  DETECTED="$(ls /dev/cu.usbmodem* 2>/dev/null | head -1)"
  [[ -n "$DETECTED" ]] && PORT="$DETECTED"
fi

echo "=== usb-hid-s3 deploy ==="
echo "  Project: $PROJECT_DIR"
echo "  Env:     $ENV_NAME"
echo "  Port:    ${PORT:-<auto>}"
echo ""

cd "$PROJECT_DIR"

echo "Compiling..."
if ! "$PIO" run -e "$ENV_NAME"; then
  echo "Compile failed."
  exit 1
fi
echo "Compile OK."

if [[ "${BUILD_ONLY:-0}" == "1" ]]; then
  echo "BUILD_ONLY set; skipping upload."
  exit 0
fi

echo ""
echo "Uploading. If it stalls: hold BOOT, tap RESET, release BOOT."
echo ""

UPLOAD_ARGS=(run -e "$ENV_NAME" -t upload)
[[ -n "$PORT" ]] && UPLOAD_ARGS+=(--upload-port "$PORT")

while true; do
  if "$PIO" "${UPLOAD_ARGS[@]}"; then
    echo "Upload complete."
    exit 0
  fi
  echo "Upload failed. Retrying in 5 s (put board in download mode)..."
  sleep 5
done
