# usb-hid-s3

A composite **USB HID mouse + keyboard** device on the ESP32-S3 (native USB-OTG
via the ESP32 core USB stack — `USBHIDMouse` + `USBHIDKeyboard` + `USBCDC`), with
USB-CDC serial logging/commands, and mutually exclusive WiFi *or* BLE connectivity
for future remote control (e.g. an iOS app).

This is the successor to `../legacy-ble-c6` (ESP32-C6 BLE-HID mouse jiggler +
AWS IoT). Lessons and reusable tooling were carried over; the HID transport
moved from BLE to native USB.

## Hardware

- Waveshare ESP32-S3-Zero (4 MB flash) — confirm with `scripts` / `esptool flash-id`.
- Flash via the native USB port. In USB-OTG mode auto-reset fails, so flashing is a
  two-step manual dance: (1) enter download mode — hold **BOOT**, tap **RESET**,
  release **BOOT** (or unplug, hold BOOT, replug, release); (2) after upload,
  **power-cycle** (unplug/replug) to boot the app into OTG so it enumerates as HID.
  `scripts/flash_and_verify.sh` automates the wait + verify around both steps.

## Layout

```
usb-hid-s3/
  platformio.ini      # esp32s3 firmware env + native unit-test env
  include/            # Config.h, Logging.h (Arduino-side headers)
  src/main.cpp        # USB/HID/serial glue (hardware)
  lib/                # pure, unit-testable logic (CommandParser, JiggleEngine, RadioMode)
  test/               # PlatformIO native unit tests (pio test -e native)
  tests/              # pytest integration + on-Mac E2E
  scripts/            # deploy.sh, serial_monitor.sh, e2e.sh, install_test_deps.sh
  docs/PHASE_LOG.md   # per-phase implementation + test results
```

## Quick start

```bash
cp config.env.example config.env      # set ESP_PORT
./scripts/deploy.sh                    # build + upload
./scripts/serial_monitor.sh           # stream logs + send commands
./scripts/serial_monitor.sh -c "move 40 0"   # one-shot command
```

## Serial commands

`move <dx> <dy> [wheel]` · `click [left|right|middle]` · `type <text>` ·
`key <name>` · `jiggle on|off|status` · `radio wifi|ble|none` ·
`wifi status|set|clear` · `status` · `version` · `help`

WiFi credentials persist in NVS. With no STA creds, `radio wifi` starts Soft-AP
`usb-hid-s3-setup` (open) with a setup page + REST at `http://192.168.4.1/api/wifi`.
With creds, STA joins and exposes:

- **HTTP REST** on `:80` — `GET /api/status`, `GET|POST /api/jiggle`,
  `POST /api/move|type|key|click`, plus `/api/wifi`
- **TCP line control** on `:3333` (same grammar as serial)

On STA the device also advertises **mDNS** as `hid-helper.local` (HTTP service
on port 80), so apps can discover it without a hard-coded IP.

### Status LED (onboard WS2812, GPIO21)

| Appearance | Meaning |
|------------|---------|
| Solid red | WiFi disconnected (radio off / not associated) |
| Magenta blink | Soft-AP setup mode (`usb-hid-s3-setup`) |
| Dim solid green | STA connected, jiggle **off** |
| Cyan breathing | STA connected, jiggle **on** |

OpenAPI / Swagger: [`docs/openapi.yaml`](docs/openapi.yaml)  
(Paste into [Swagger Editor](https://editor.swagger.io/) or generate clients from it.)

Example:

```bash
curl http://hid-helper.local/api/status
curl -X POST http://hid-helper.local/api/jiggle -H 'Content-Type: application/json' -d '{"enabled":true}'
curl -X POST http://hid-helper.local/api/move -H 'Content-Type: application/json' -d '{"dx":40,"dy":0}'
curl -X POST http://hid-helper.local/api/type -H 'Content-Type: application/json' -d '{"text":"hello"}'
```

## Testing

```bash
pio test -e native                     # unit tests (host, no hardware)
./scripts/e2e.sh                       # pytest integration + E2E (needs board + Mac perms)
```

E2E on macOS uses `system_profiler`/`ioreg`/`hidutil` to verify enumeration and a
pyobjc `CGEventTap` to confirm the cursor actually moves and keystrokes arrive.
Grant your terminal **Input Monitoring** and **Accessibility** permission.

See `docs/PHASE_LOG.md` for detailed build/test history.
