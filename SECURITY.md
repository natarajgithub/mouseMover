# Security policy

## What this project does

`usb-hid-s3` presents itself to a host PC as a **USB mouse and keyboard**, and
can also accept control commands over **USB-CDC serial**, **WiFi HTTP/TCP**, and
**BLE UART**. Anyone who can reach those surfaces can move the cursor and inject
keystrokes on the attached computer.

Treat the device like a physical keyboard you left plugged in.

## Default network posture (important)

Out of the box:

| Surface | Default |
|---------|---------|
| Soft-AP `usb-hid-s3-setup` | **Open** (no password) while provisioning |
| HTTP REST (`:80`) | **No authentication** |
| TCP line control (`:3333`) | **No authentication** |
| BLE NUS control | Pairing/bonding not required by default |
| USB HID / CDC | Available to the host that enumerates the device |

Anyone on the Soft-AP or the same LAN can call the REST/TCP APIs and type or
move the mouse on the host PC. Use only on trusted networks, or harden before
exposing the device beyond a lab.

## USB identity

The firmware uses hobbyist USB IDs (`VID 0xCAFE`, `PID 0x4001`). These are **not**
USB-IF assigned IDs. Do not ship commercial products with them; collisions are
possible in unusual environments.

## Reporting a vulnerability

Please open a **private** security advisory on GitHub (Security → Advisories →
New draft advisory), or contact the repository owner. Do not file a public issue
for exploitable flaws that expand remote HID injection beyond the documented
defaults.

Include: firmware version (`version` command / `/api/status`), board model, and
steps to reproduce.
