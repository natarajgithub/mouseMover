# Known issues, pitfalls, and fixes (usb-hid-s3)

Carried-over lessons and new ESP32-S3 USB specifics. Update as issues are found.

## USB stack: use the ESP32 core USB, NOT Adafruit TinyUSB

We initially used Adafruit TinyUSB (`USE_TINYUSB` + `Adafruit_USBD_HID`). It
enumerated and serial TX worked, but **serial RX was completely dead** — the host
could not send commands. Cause: with `USE_TINYUSB` driving the device stack *and*
the core `USBCDC` both trying to own the CDC, the CDC **OUT endpoint (RX)** was left
non-functional after the re-enumeration needed for custom HID. TX (IN endpoint)
survived, RX did not. The reference `usb_telephony_mute-s3` never used `Serial`, so
it never exposed this. Fix: drop Adafruit; use the core's integrated
`USBHIDMouse` + `USBHIDKeyboard` + `USBCDC` (RX+TX + composite HID all work).

## USB / flashing

- **Native USB-OTG can't auto-reset into the bootloader.** With
  `ARDUINO_USB_MODE=0` the S3 presents USB-OTG, so esptool's RTS/DTR reset fails
  ("No serial data received"). Fix: manual **BOOT+RESET** (hold BOOT, tap RESET,
  release BOOT); or unplug, hold BOOT, replug, release. `flash_and_verify.sh`
  retries upload in a loop so you can do this any time.
- **A power-cycle is required after flashing.** esptool leaves the S3 in
  USB-Serial-JTAG mode after upload; unplug/replug the cable to boot the app into
  native USB-OTG so it enumerates as `0xCAFE` HID. `flash_and_verify.sh` waits for
  this and polls `system_profiler` for `0xcafe`.
- **`ARDUINO_USB_MODE` must be forced to 0.** The `esp32-s3-devkitc-1` manifest
  hard-codes `-DARDUINO_USB_MODE=1` in `build.extra_flags`, and pioarduino appends
  it *after* `build_unflags`, so `=1` wins → `Serial`/USB bind to the USB-Serial-JTAG
  unit (no HID, no `0xCAFE`). Fix: **override the whole list** via
  `board_build.extra_flags` so `ARDUINO_USB_MODE=0` is the only USB-mode define.
- **`ARDUINO_USB_CDC_ON_BOOT` must be 0.** With `=1` the core calls `USB.begin()`
  *before* `setup()` using the default `0x303a/0x1001` and no HID; `ESPUSB::begin()`
  inits TinyUSB only once, so any identity/HID set in `setup()` is ignored. With `=0`
  the core does no boot-time USB, and we own the full bring-up in `setup()`:
  identity (`USB.VID/PID/productName/...`) → `Mouse.begin()` → `Keyboard.begin()` →
  `UsbSerial.begin()` (our explicit `USBCDC`) → single `USB.begin()`.
- **`Serial` is UART0 when `CDC_ON_BOOT=0`.** Logging/commands use an explicit
  `USBCDC UsbSerial(0)` (see `main.cpp` / `Logging.h`), not `Serial`.
- **4 MB flash partition.** The `esp32-s3-devkitc-1` profile defaults to an 8 MB
  table that boot-loops on the 4 MB Waveshare S3-Zero. Fixed via
  `board_build.flash_size = 4MB` + `board_build.partitions = max_app_4MB.csv`.
  (The `pio` size check still prints "8388608" — cosmetic; actual flash ops use 4 MB.)
- **esp-idf-size 2.x** removed `--ng`; a pre-build hook pins 1.x if needed.

## USB macro collision

- The S3 variant `pins_arduino.h` already defines `USB_VID`/`USB_PID`/
  `USB_MANUFACTURER`/`USB_PRODUCT` (unconditionally — so build-flag overrides don't
  cleanly work; set identity at runtime via `USB.VID()`/etc. before `USB.begin()`).
  Our identity macros are prefixed `HID_USB_*` to avoid redefinition warnings.

## HID behaviour

- Relative mouse deltas are `int8` (−127..127). `hidMouseMove()` chunks larger
  moves into multiple `Mouse.move()` reports. Buttons: `MOUSE_LEFT/RIGHT/MIDDLE`.
- `type` uses `Keyboard.write(ch)` (ASCII → keypress/release via the core layout).
  `key <name>` uses `KeyMap` → a `KeyReport{modifiers, keys[6]}` of **raw HID usage
  codes** sent via `Keyboard.sendReport()`, then an empty report to release
  (enter, esc, tab, arrows, F-keys, `cmd+space`, `ctrl+shift+t`, ...).
- Readiness is checked via a standalone `USBHID::ready()` (global `tud_hid_n_ready`).

## WiFi / BLE coexistence

- Single 2.4 GHz radio → only **one control transport is active at a time**.
  `RadioManager::setMode()` stops the current radio before starting the other.
  USB is a separate peripheral and is unaffected by radio changes (validated:
  `move` over serial keeps working across `ble`/`wifi`/`none` switches).
- **Do NOT `NimBLEDevice::deinit()` to stop BLE.** On arduino-esp32 3.2.1 /
  IDF 5.4, `deinit()` (→ `nimble_port_deinit` → `esp_bt_controller_deinit`)
  **crashes and reboots the S3** — even after `stopAdvertising()` with no client
  connected (NimBLE-Arduino upstream bug #1008; #724 covers the connected case).
  Symptom: `radio none`/`radio wifi` from BLE dropped the USB CDC ("Device not
  configured") and reset uptime. Fix in `RadioManager::stopBle()`: **never
  deinit** — just `stopAdvertising()` + disconnect clients, leaving the NimBLE
  stack initialized but idle. The GATT server is created once (lazily on first
  `radio ble`); re-selecting BLE re-advertises instantly. `s_bleTearingDown`
  guards `onDisconnect` so it doesn't re-advertise mid-teardown.
  - Trade-off: once BLE has been used, its controller stays powered until the
    next reboot (it coexists fine with WiFi — validated `ble→wifi` direct
    switch). The *control transport* is still exclusive (advertising off, clients
    dropped). If BLE is never selected, its controller never powers up.
- WiFi STA credentials live in **NVS** (`WifiCredentials`). First boot seeds
  from compile-time `WIFI_SSID`/`WIFI_PASS` (`wifi_secrets.h` or `-D` flags) if
  present. After that NVS is authoritative.
  - `wifi clear` → empty NVS (provisioned) → Soft-AP `usb-hid-s3-setup` + HTTP
    portal/REST on `:80` (`GET/POST /api/wifi`) when `radio wifi` is selected.
  - `wifi set <ssid> <pass>` (serial) or `POST /api/wifi` (Soft-AP) saves NVS
    and reconnects STA. STA control remains TCP `:3333` (HTTP control wrapper
    is a follow-on).
  - Must be a **2.4 GHz** network (S3 has no 5 GHz).
  - Soft-AP is open (`WIFI_AP_PASS` empty) for easiest phone/app setup; tighten
    before production if needed.

## macOS E2E

- Keystroke/mouse capture via `CGEventTap` requires the terminal/Python to have
  **Input Monitoring** (and often **Accessibility**) permission, else the tap
  can't be created and those tests skip. Cursor-position checks (mouse move) need
  no permission.
- E2E deliberately moves the real cursor and types; focus a scratch window for
  `type` tests and keep hands off the trackpad during a run.
