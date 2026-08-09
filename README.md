# mouseMover

[![CI](https://github.com/natarajgithub/mouseMover/actions/workflows/ci.yml/badge.svg?branch=main)](https://github.com/natarajgithub/mouseMover/actions/workflows/ci.yml)
[![Firmware + unit tests](https://img.shields.io/github/actions/workflow/status/natarajgithub/mouseMover/ci.yml?branch=main&job=Native%20unit%20tests%20%2B%20firmware%20build&label=firmware%20%2B%20unit%20tests)](https://github.com/natarajgithub/mouseMover/actions/workflows/ci.yml)
[![OpenAPI](https://img.shields.io/github/actions/workflow/status/natarajgithub/mouseMover/ci.yml?branch=main&job=OpenAPI%20lint&label=OpenAPI)](https://github.com/natarajgithub/mouseMover/actions/workflows/ci.yml)

**mouseMover** is an ESP32-S3 firmware that appears to your PC as a USB mouse +
keyboard (**hid-helper**), with optional WiFi/BLE remote control.

| Name | Where you see it |
|------|------------------|
| **mouseMover** | GitHub repository |
| **usb-hid-s3** | Firmware folder / USB product family name |
| **hid-helper** | mDNS hostname (`hid-helper.local`) |

## Getting started

### 1. Hardware

Supported board: **Waveshare ESP32-S3-Zero / Mini** (ESP32-S3FH4R2, 4 MB flash,
WS2812 on GPIO21).

- Buy example: [Amazon listing](https://a.co/d/0fwrWUFU)
- Details: [`usb-hid-s3/docs/HARDWARE.md`](usb-hid-s3/docs/HARDWARE.md)

### 2. Build & flash

```bash
cd usb-hid-s3
cp include/wifi_secrets.h.example include/wifi_secrets.h   # optional STA seed
cp config.env.example config.env                             # set ESP_PORT
# Enter download mode: hold BOOT, tap RESET, release BOOT
pio run -e esp32s3 -t upload
# Power-cycle the USB cable so the app enumerates as VID 0xCAFE
curl http://hid-helper.local/api/status
```

Full commands, LED legend, and REST examples:
[`usb-hid-s3/README.md`](usb-hid-s3/README.md)  
OpenAPI: [`usb-hid-s3/docs/openapi.yaml`](usb-hid-s3/docs/openapi.yaml)

### 3. Platform support

| Check | Where it runs |
|-------|----------------|
| Native unit tests (`pio test -e native`) | Linux / macOS / CI |
| Firmware compile (`pio run -e esp32s3`) | Linux / macOS / CI |
| On-device pytest (serial / HID E2E / WiFi / BLE / mDNS) | **macOS + board** only |

## Layout

| Folder | Purpose |
|--------|---------|
| [`usb-hid-s3/`](usb-hid-s3/) | ESP32-S3 firmware (USB HID + WiFi REST + Soft-AP + mDNS) |
| [`ios/`](ios/) | **Mouse Mover** iOS companion app (SwiftUI, Bonjour discovery, REST control) |

## CI

Badges above track the latest `main` workflow run
(`.github/workflows/ci.yml` on every PR and push to `main`):

- PlatformIO **native unit tests**
- **esp32s3 firmware compile**
- OpenAPI YAML sanity check

## Docs

- [`CHANGELOG.md`](CHANGELOG.md) — version history
- [`usb-hid-s3/docs/HARDWARE.md`](usb-hid-s3/docs/HARDWARE.md) — BOM & flash dance
- [`usb-hid-s3/docs/KNOWN_LIMITATIONS.md`](usb-hid-s3/docs/KNOWN_LIMITATIONS.md)
## Secrets

Do **not** commit:

- `usb-hid-s3/include/wifi_secrets.h`
- `usb-hid-s3/config.env`
- any app signing keys / `local.properties` / `.env` files

HID keyboard injection can look like malware to AV / IT policies. Use on systems
you own or have permission to automate.
