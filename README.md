# mouseMover

USB HID mouse/keyboard helper (ESP32-S3) plus companion apps.

## Layout

| Folder | Purpose |
|--------|---------|
| [`usb-hid-s3/`](usb-hid-s3/) | ESP32-S3 firmware (USB HID + WiFi REST + Soft-AP setup + mDNS) |
| `ios/` | iOS app (planned) |
| `android/` | Android app (planned) |

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

## Secrets

Do **not** commit:

- `usb-hid-s3/include/wifi_secrets.h`
- `usb-hid-s3/config.env`
- any app signing keys / `local.properties` / `.env` files
