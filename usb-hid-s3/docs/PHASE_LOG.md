# usb-hid-s3 — Phase Log

Running record of implementation and test results for each phase. The next phase
starts by reading this file.

Legend: PENDING / IN PROGRESS / DONE / DONE (on-device pending) / BLOCKED.

> Hardware-flash note: the ESP32-S3 runs in native USB-OTG mode, so it cannot
> auto-reset into the bootloader. Every flash needs a manual **BOOT+RESET**
> (hold BOOT, tap RESET, release BOOT), then a **power-cycle** (unplug/replug) to
> boot the app into OTG. Because of this single manual bottleneck, firmware for all
> phases was implemented and compile-verified first; the on-device validation
> (integration + enumeration + E2E) is run in one consolidated pass after flashing.

---

## Milestone — on-device bring-up validated (USB stack: Adafruit TinyUSB → core USB)

Status: DONE (on-device, 2026-07-19)

The initial Adafruit-TinyUSB composite enumerated but **serial RX was dead** (host
could not send commands). Root-caused and fixed by moving to the ESP32 core's native
USB stack (`USBHIDMouse` + `USBHIDKeyboard` + `USBCDC`). Three sequential bugs were
found and fixed on real hardware:

1. **Serial RX dead (Adafruit TinyUSB).** With `USE_TINYUSB` (Adafruit) driving the
   device stack *and* the core `USBCDC`, the CDC OUT endpoint was left non-functional
   after the re-enumeration needed for custom HID — TX worked, RX did not. The
   reference `usb_telephony_mute-s3` never used `Serial`, so it never surfaced.
   → Dropped Adafruit; use the core's integrated `USBHID` + `USBCDC`.
2. **Bound to USB-Serial-JTAG, not OTG.** The `esp32-s3-devkitc-1` manifest hard-codes
   `-DARDUINO_USB_MODE=1` in `build.extra_flags`, appended after `build_unflags`, so
   `=1` won and `Serial`/USB bound to the JTAG unit (no HID, no `0xCAFE`).
   → Replaced the board's `extra_flags` so `ARDUINO_USB_MODE=0` is the only USB-mode define.
3. **Boot-time `USB.begin()` locked out our identity + HID.** With
   `ARDUINO_USB_CDC_ON_BOOT=1` the core calls `USB.begin()` *before* `setup()` using the
   default `0x303a/0x1001` and no HID; `ESPUSB::begin()` inits TinyUSB only once, so our
   `setup()` VID/PID + `Mouse.begin()`/`Keyboard.begin()` were ignored.
   → Set `ARDUINO_USB_CDC_ON_BOOT=0` and own the whole bring-up in `setup()`
     (identity → HID → CDC (`UsbSerial`) → single `USB.begin()`).

Results (flash → power-cycle → verify):
- **Native unit tests:** 28/28 PASS.
- **Enumeration:** `test_usb_device_enumerates` PASS (VID 0xCAFE / PID 0x4001,
  "S3 Mouse+Keyboard" / "MKF Labs"); `test_hid_has_mouse_and_keyboard` PASS.
- **Integration (serial RX+TX):** 13/13 PASS — version, help, status, move (+invalid),
  click, type, key, key-combo, jiggle toggle, unknown-command.
- **E2E (real cursor/keystroke on the Mac):** 4/4 PASS — `test_move_moves_cursor`,
  `test_type_produces_keystrokes` (typed "abc"), `test_key_enter_produces_keystroke`,
  `test_jiggle_moves_then_stops`. Keyboard-capture tests need macOS Input Monitoring
  granted to the terminal running pytest (run with `RUN_E2E=1`).

Toolchain note: framework-arduinoespressif32 3.2.1, core `USB @ 3.2.1`, NimBLE 2.5.0.
`scripts/flash_and_verify.sh` now waits for the power-cycle, polls for `0xCAFE`, and
runs the suite. `serial_harness.py` asserts DTR (core `USBCDC` gates TX on DTR).

---

## Phase 0 — Restructure + toolchain + board bring-up

Status: DONE (on-device pending)

### Implemented
- Repo restructured: previous MouseJiggler6 files moved to `legacy-ble-c6/`;
  new project in `usb-hid-s3/`. `.git` stays at repo root; root `.gitignore` added.
- `platformio.ini`: `esp32-s3-devkitc-1`, 4 MB overrides (`max_app_4MB.csv`),
  USB-OTG/TinyUSB flags (`ARDUINO_USB_MODE=0`, `ARDUINO_USB_CDC_ON_BOOT=1`,
  `USE_TINYUSB`), `-I include`, `esp-idf-size` compat pre-hook, `native` unit-test env.
- `include/Logging.h` (tagged logs), `include/Config.h` (FW_VERSION, USB identity,
  HID report IDs, jiggle/serial/radio config).
- `scripts/deploy.sh` (pio upload + retry), `scripts/serial_monitor.sh` (pyserial
  log stream + command send), `config.env.example`, `README.md`.

### Test results
- Host build `pio run -e esp32s3`: PASS (Phase 0 hello-world, 435 KB).
- Board detection: the pre-existing firmware enumerated as USB VID 0xCAFE /
  "Mac System Mute" (the `usb_telephony_mute-s3` build), i.e. the same Waveshare
  ESP32-S3-Zero (4 MB). `esptool flash-id` auto-connect failed (expected in
  USB-OTG mode); definitive flash-size confirmation happens on the first manual
  BOOT+RESET flash, and the firmware boot banner also prints `flash=` bytes.
- Flash + serial boot banner: PENDING (needs BOOT+RESET).

---

## Phase 1 — Composite USB HID + serial commands

Status: DONE (on-device pending)

### Implemented
- Pure logic libs (Arduino-free, unit-tested):
  - `lib/CommandParser` — parses move/click/type/key/jiggle/radio/status/version/help.
  - `lib/JiggleEngine` — deterministic (xorshift) bounded jiggle timing + delta.
  - `lib/KeyMap` — key name/combo -> HID usage + modifier (enter, cmd+space, F1..F12, ...).
- `src/main.cpp` — Adafruit TinyUSB composite descriptor
  `TUD_HID_REPORT_DESC_KEYBOARD(RID 1)` + `TUD_HID_REPORT_DESC_MOUSE(RID 2)`;
  USB init order proven on this board (begin → setID/descriptors → usb_hid.begin →
  detach/attach); mutex-guarded HID helpers (mouse move chunked to int8, click,
  type, key); FreeRTOS `jiggleTask`; non-blocking serial command service; boot
  banner + heartbeat. Custom identity VID 0xCAFE / PID 0x4001 / "S3 Mouse+Keyboard".

### Test results
- Native unit tests `pio test -e native`: PASS (28/28 — parser 12, jiggle 6, keymap 7, radio 3).
- Host build `pio run -e esp32s3`: PASS (no warnings after renaming USB_* macros to HID_USB_*).
- On-device (enumerate as composite mouse+keyboard; serial commands move/type): PENDING.

---

## Phase 2 — Test suite (unit + integration + E2E)

Status: DONE (on-device pending)

### Implemented
- Native unit tests under `test/` (run above).
- pytest harness `tests/harness/`:
  - `serial_harness.py` — background reader, `wait_for_pattern`, `send_and_wait`.
  - `mac_hid.py` — enumeration via `system_profiler -json` + HID usages via `ioreg`.
  - `mac_input.py` — cursor position (Quartz) + `CGEventTap` keystroke/mouse capture.
- pytest tests `tests/e2e/`:
  - `test_integration_serial.py` — send command, assert tagged log (`@integration`).
  - `test_enumeration.py` — device present + mouse+keyboard HID usages (`@enumeration`).
  - `test_hid_actions.py` — cursor moves on move/jiggle; keystrokes on type/key (`@e2e`).
- `scripts/e2e.sh`, `scripts/install_test_deps.sh`, `scripts/smoke_test.sh`,
  `requirements-test.txt`, `pytest.ini`.

### Test results
- Native unit suite: PASS (28/28).
- Integration + enumeration + E2E (need flashed board): PENDING.

---

## Phase 3 — Radio layer (WiFi xor BLE)

Status: DONE (on-device pending)

### Implemented
- `lib/RadioMode` (pure enum + string mapping, unit-tested).
- `lib/RadioManager` — mutually-exclusive WiFi STA *or* BLE; `begin(default)` +
  `setMode()` tears down the other stack first; `loop()` services transport;
  `statusStr()` for logs/heartbeat. Default via `RADIO_MODE_DEFAULT_STR` (code),
  runtime via `radio wifi|ble|none`. USB HID is independent of the radio.

### Test results
- Host build with NimBLE 2.5.0 + WiFi linked: PASS (1.19 MB flash, 19.6% RAM).
- On-device (switch modes; only one active; USB unaffected; heap stable): PASS
  — see "Radio on-device validation (2026-07-19)" below.

---

## Phase 4 — Control abstraction + polish

Status: DONE (on-device pending)

### Implemented
- `include/CommandSink.h` — single `handleCommandLine(line, source)` entry used by
  serial, BLE, and WiFi transports (transport-agnostic control surface).
- BLE: Nordic UART Service (NUS) RX characteristic routes writes into
  `handleCommandLine(..., "ble")`; TX notify for responses — ready for an iOS app.
- WiFi: TCP line server on `WIFI_CONTROL_PORT` routes lines into
  `handleCommandLine(..., "wifi")`.
- Docs: `README.md`, `docs/ISSUES.md`, this `PHASE_LOG.md`.

### Test results
- Host build: PASS. Full regression (unit + integration + E2E): PASS on-device.
- BLE (NUS) + WiFi (TCP) control transports validated — see "Radio on-device
  validation (2026-07-19)" below.

---

## On-device validation checklist (run after BOOT+RESET flash)

1. `./scripts/deploy.sh` flashes; `./scripts/serial_monitor.sh` shows boot banner +
   `chip=ESP32-S3 flash=... boot-ok`.
2. `system_profiler SPUSBDataType | grep -A6 "S3 Mouse+Keyboard"` shows VID 0xCAFE / PID 0x4001.
3. `./scripts/e2e.sh -m integration` — serial command acks.
4. `./scripts/e2e.sh -m enumeration` — mouse+keyboard HID usages.
5. `./scripts/e2e.sh -m e2e` — cursor moves + keystrokes captured (needs Input Monitoring perm).
6. `radio ble` then scan for `usb-hid-s3`; `radio wifi` (with creds) then `nc <ip> 3333`.

---

## HTTP REST control API (2026-08-08)

Status: DONE — on-device validated (STA `192.168.2.161`, pytest 5/5).

### Endpoints (STA IP or Soft-AP `192.168.4.1`, port 80)
- `GET /api/status` — version, uptime, heap, usb, jiggle, sta_ip
- `GET|POST /api/jiggle` — `{"enabled": true|false}`
- `POST /api/move` — `{"dx","dy","wheel"?}`
- `POST /api/type` — `{"text"}`
- `POST /api/key` — `{"key"}`
- `POST /api/click` — `{"button"}`
- WiFi provisioning routes unchanged (`/api/wifi`).
- Commands use `handleCommandLine(..., "http")`. FW **0.3.0**.
- Tests: `tests/e2e/test_http_control.py` (`RUN_WIFI=1`).

---

## WiFi NVS + Soft-AP provisioner (2026-08-08)

Status: IMPLEMENTED (on-device tests after flash).

### Implemented
- `lib/WifiCredentials` — Preferences NVS; first-boot seed from compile-time
  `WIFI_SSID`; `clear()` forces Soft-AP even if secrets remain in the binary.
- `lib/WifiConfigServer` — Soft-AP HTTP portal + REST:
  `GET/POST /api/wifi`, `POST /api/wifi/clear`, CORS for future apps.
- `RadioManager` — no NVS SSID → Soft-AP `usb-hid-s3-setup`; STA timeout falls
  back to Soft-AP; `applyWifiCredentials()` restarts WiFi after set/clear.
- Serial: `wifi status|set|clear`. FW bumped to **0.2.0**.
- Tests: native `test_wifi` parser; `tests/e2e/test_wifi_provision.py`
  (`RUN_WIFI=1`; optional `RUN_WIFI_AP_REST=1` for Soft-AP REST via join).

### Next
- HTTP REST wrapper on STA for jiggle/move/type (same command sink).

---

## Radio on-device validation (2026-07-19)

Status: DONE — BLE + WiFi control transports validated on hardware.

### BLE (Nordic UART Service)
- `radio ble` → logs `advertising as 'usb-hid-s3' (NUS control)`; `bleak` finds the
  device by service UUID `6e400001-...`.
- Connected a BLE central, wrote `move 33 0` to the NUS RX char
  (`6e400002-...`) → firmware logged `src=ble line="move 33 0"` → `HID move ok`
  → **real USB mouse moved**. `type`/`click` over BLE also reach the HID layer.
- Repeatable pytest: `tests/e2e/test_ble_control.py` (`-m ble`, needs `RUN_BLE=1`
  + `bleak` + macOS Bluetooth permission) — **3/3 pass**.

### WiFi (TCP control)
- Flashed creds via untracked `include/wifi_secrets.h` (local home SSID).
- `radio wifi` → `connected ip=192.168.2.161 control-port=3333`.
- TCP connect to `192.168.2.161:3333`, sent `move 41 0` → `src=wifi` →
  `HID move ok dx=41` → **real USB mouse moved**. `type`/`click` over TCP also work.
- Repeatable pytest: `tests/e2e/test_wifi_control.py` (`-m wifi`, needs `RUN_WIFI=1`
  + creds flashed + host on same LAN) — **3/3 pass**.

### Exclusivity / stability
- Cycled `none→ble→none` twice and `ble→wifi` directly: uptime climbed
  monotonically (34→41→50→62 s) — **no reboot, no USB CDC drop**.
- USB HID `move` kept working after every switch (USB independent of radio).
- Only one control transport active at a time (setMode stops the other first).

### Bug found + fixed: BLE teardown rebooted the S3
- **Symptom:** switching *out* of BLE (`radio none`/`radio wifi`) dropped the USB
  CDC ("Device not configured") and reset uptime → device rebooted.
- **Root cause:** `NimBLEDevice::deinit()` crashes on arduino-esp32 3.2.1 / IDF 5.4
  (upstream `esp_bt_controller_deinit`, NimBLE #1008), even after `stopAdvertising`
  with no client connected.
- **Fix:** `RadioManager::stopBle()` no longer deinits — it stops advertising +
  drops clients and leaves the NimBLE stack idle; the GATT server is built once
  (lazily) and re-advertised on re-select. See `docs/ISSUES.md`.
- Verified over multiple reflashes: crash gone; all switches stable.

### Regression after fix
- Native unit: 28/28 PASS. Device integration + enumeration: 13/13 PASS.
- Radio: BLE 3/3 + WiFi 3/3 PASS.
