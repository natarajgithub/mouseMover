#!/usr/bin/env bash
# Quick smoke test: compile firmware + run native unit tests. No hardware needed.
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$PROJECT_DIR"

PIO="${PIO:-$HOME/.platformio/penv/bin/pio}"
command -v "$PIO" >/dev/null 2>&1 || PIO="pio"

echo "=== Compile firmware (esp32s3) ==="
"$PIO" run -e esp32s3

echo "=== Native unit tests ==="
"$PIO" test -e native

echo "Smoke test OK."
