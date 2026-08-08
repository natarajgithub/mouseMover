#!/usr/bin/env bash
# Run the usb-hid-s3 test suite: native unit tests + on-device pytest (integration,
# enumeration, e2e). Requires a flashed, connected board for the device tests.
#
# Usage:
#   ./scripts/e2e.sh                 Native units + all device tests
#   ./scripts/e2e.sh --deploy        Build+upload first, then test
#   ./scripts/e2e.sh --unit-only     Only native unit tests (no hardware)
#   ./scripts/e2e.sh -m integration  Pass extra args to pytest (marker filter)

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$PROJECT_DIR"

PIO="${PIO:-$HOME/.platformio/penv/bin/pio}"
command -v "$PIO" >/dev/null 2>&1 || PIO="pio"
PY="${PYTHON:-python3}"

DEPLOY=0
UNIT_ONLY=0
PYTEST_ARGS=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    --deploy) DEPLOY=1; shift ;;
    --unit-only) UNIT_ONLY=1; shift ;;
    *) PYTEST_ARGS+=("$1"); shift ;;
  esac
done

if [[ -f "$PROJECT_DIR/config.env" ]]; then
  set -a; . "$PROJECT_DIR/config.env"; set +a
fi

echo "=== Native unit tests (pio test -e native) ==="
"$PIO" test -e native

if [[ "$UNIT_ONLY" == "1" ]]; then
  echo "Unit-only run complete."
  exit 0
fi

if [[ "$DEPLOY" == "1" ]]; then
  echo "=== Deploy ==="
  "$SCRIPT_DIR/deploy.sh"
fi

echo "=== Device tests (pytest) ==="
mkdir -p "$PROJECT_DIR/tests/output"
exec "$PY" -m pytest "$PROJECT_DIR/tests/e2e" \
  --junitxml="$PROJECT_DIR/tests/output/junit.xml" \
  "${PYTEST_ARGS[@]}"
