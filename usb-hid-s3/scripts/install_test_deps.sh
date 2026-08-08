#!/usr/bin/env bash
# Install Python test dependencies for the usb-hid-s3 test suite.
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

PY="${PYTHON:-python3}"
echo "Installing test deps with $PY ..."
"$PY" -m pip install -r "$PROJECT_DIR/requirements-test.txt"

echo ""
echo "Done. For macOS E2E keystroke capture, grant your terminal:"
echo "  System Settings > Privacy & Security > Input Monitoring (and Accessibility)"
