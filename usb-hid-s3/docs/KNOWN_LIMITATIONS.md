# Known limitations

- **No auth by default** on Soft-AP, HTTP, TCP, or BLE control (open Soft-AP,
  unauthenticated REST/TCP). See root `SECURITY.md` when present.
- Soft-AP `usb-hid-s3-setup` is **open** unless you set `WIFI_AP_PASS`.
- USB VID/PID (`0xCAFE` / `0x4001`) are hobbyist IDs, not USB-IF assigned.
- Flashing requires manual **BOOT+RESET**, then a **power-cycle** for HID
  enumeration (OTG auto-reset is unreliable).
- On-device pytest E2E (HID cursor / keystroke proof) is **macOS-only**.
- WiFi and BLE are mutually exclusive; only one radio mode is active.
- BLE teardown deliberately avoids `NimBLEDevice::deinit()` (upstream crash on
  Arduino-ESP32 3.2.x / IDF 5.4).
- Companion iOS/Android apps are not in this repository yet.
