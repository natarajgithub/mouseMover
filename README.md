# mouseMover

[![CI](https://github.com/natarajgithub/mouseMover/actions/workflows/ci.yml/badge.svg?branch=main)](https://github.com/natarajgithub/mouseMover/actions/workflows/ci.yml)
[![Firmware + unit tests](https://img.shields.io/github/actions/workflow/status/natarajgithub/mouseMover/ci.yml?branch=main&job=Native%20unit%20tests%20%2B%20firmware%20build&label=firmware%20%2B%20unit%20tests)](https://github.com/natarajgithub/mouseMover/actions/workflows/ci.yml)
[![OpenAPI](https://img.shields.io/github/actions/workflow/status/natarajgithub/mouseMover/ci.yml?branch=main&job=OpenAPI%20lint&label=OpenAPI)](https://github.com/natarajgithub/mouseMover/actions/workflows/ci.yml)

USB HID mouse/keyboard helper firmware for ESP32-S3 (native USB + WiFi REST).

## Layout

| Folder | Purpose |
|--------|---------|
| [`usb-hid-s3/`](usb-hid-s3/) | ESP32-S3 firmware (USB HID + WiFi REST + Soft-AP setup + mDNS) |

## Firmware quick start

```bash
cd usb-hid-s3
cp include/wifi_secrets.h.example include/wifi_secrets.h   # edit SSID/pass
cp config.env.example config.env                             # optional serial port
pio run -e esp32s3 -t upload                                 # BOOT+RESET for native USB
# power-cycle cable, then:
curl http://hid-helper.local/api/status
```

See [`usb-hid-s3/README.md`](usb-hid-s3/README.md) for commands, REST API, LED legend, and tests.  
OpenAPI spec: [`usb-hid-s3/docs/openapi.yaml`](usb-hid-s3/docs/openapi.yaml).

## CI

Badges above track the latest `main` workflow run. GitHub Actions
(`.github/workflows/ci.yml`) runs on every PR and on pushes to `main`:

- PlatformIO **native unit tests** (`pio test -e native`)
- **esp32s3 firmware compile** (`pio run -e esp32s3`)
- OpenAPI YAML sanity check

On-device pytest (serial / HID E2E / WiFi / BLE / mDNS) requires a Mac + board
and is not run in CI.

## Secrets

Do **not** commit:

- `usb-hid-s3/include/wifi_secrets.h`
- `usb-hid-s3/config.env`
- any app signing keys / `local.properties` / `.env` files
