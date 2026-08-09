# Changelog

All notable changes to **mouseMover** / `usb-hid-s3` are documented here.
Firmware version is `FW_VERSION` in `usb-hid-s3/include/Config.h`.

## 0.3.3

- USB HID mouse + keyboard (ESP32 core native USB-OTG)
- USB-CDC serial command interface
- WiFi XOR BLE radio control (NUS / TCP `:3333` / HTTP `:80`)
- Soft-AP WiFi provisioning portal (`usb-hid-s3-setup`)
- mDNS hostname `hid-helper.local`
- WS2812 status LED (GPIO21, RGB order)
- OpenAPI 3 spec at `usb-hid-s3/docs/openapi.yaml`
- Cloud CI: native unit tests + firmware compile + OpenAPI check
