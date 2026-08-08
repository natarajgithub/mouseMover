#ifndef CONFIG_H
#define CONFIG_H

/**
 * Compile-time configuration for the USB HID S3 firmware.
 * Values the test suite reads back (FW_VERSION) live here.
 */

#define FW_VERSION      "0.3.3"
#define FW_NAME         "usb-hid-s3"
// USB bcdDevice (0x0303 = v3.03) reported to the host.
#define FW_VERSION_BCD  0x0303

// --- USB identity (custom VID/PID so the host drops the boot-time Espressif id) ---
// Prefixed to avoid colliding with USB_VID/USB_PID/... from the S3 variant's
// pins_arduino.h.
#define HID_USB_VID          0xCAFE
#define HID_USB_PID          0x4001
#define HID_USB_MANUFACTURER "MKF Labs"
#define HID_USB_PRODUCT      "S3 Mouse+Keyboard"

// --- HID report IDs (composite descriptor) ---
#define HID_RID_KEYBOARD 1
#define HID_RID_MOUSE    2

// --- Jiggle behaviour (Phase 1) ---
#define JIGGLE_INTERVAL_MS 10000UL  // time between jiggle bursts
#define JIGGLE_MAX_DELTA   8         // max +/- pixels per jiggle step
#define JIGGLE_ENABLED_DEFAULT 0     // 0 = off at boot; toggle via serial

// --- Serial command interface ---
#define SERIAL_BAUD        115200
#define SERIAL_CMD_MAXLEN  256

// --- Radio (Phase 3): "none" / "wifi" / "ble" selected at runtime.
//     Default mode picked at boot; only one radio is ever active.
//     Change this to "ble" or "wifi" to switch connectivity from code. ---
#define RADIO_MODE_DEFAULT_STR "wifi"

// WiFi STA credentials. Empty by default (radio stays disconnected).
// To set them without leaking secrets into git, create an untracked
// include/wifi_secrets.h (gitignored) with:
//   #define WIFI_SSID "MyNetwork"
//   #define WIFI_PASS "supersecret"
// It's pulled in below if present; the #ifndef guards keep these as the
// fallback. (Build flags -DWIFI_SSID=... also work.)
#if defined(__has_include)
#  if __has_include("wifi_secrets.h")
#    include "wifi_secrets.h"
#  endif
#endif
#ifndef WIFI_SSID
#define WIFI_SSID ""
#endif
#ifndef WIFI_PASS
#define WIFI_PASS ""
#endif
#define WIFI_CONNECT_TIMEOUT_MS 15000UL

// Soft-AP setup portal (used when no STA credentials are available).
#define WIFI_AP_SSID     "usb-hid-s3-setup"
#define WIFI_AP_PASS     ""          // open AP for easiest phone/app setup
#define WIFI_AP_CHANNEL  1
#define WIFI_HTTP_PORT   80

// mDNS hostname on STA (browse as hid-helper.local on the LAN).
#define MDNS_HOSTNAME    "hid-helper"

// Waveshare ESP32-S3-Zero / Mini: onboard WS2812 RGB on GPIO21.
#define STATUS_LED_PIN         21
#define STATUS_LED_BRIGHTNESS  48   // 0..255 peak channel value (keep modest)

// BLE identity + Nordic UART Service (NUS) UUIDs for remote control (Phase 4).
#define BLE_DEVICE_NAME  "usb-hid-s3"
#define BLE_NUS_SERVICE_UUID "6e400001-b5a3-f393-e0a9-e50e24dcca9e"
#define BLE_NUS_RX_UUID      "6e400002-b5a3-f393-e0a9-e50e24dcca9e"  // host -> device (write)
#define BLE_NUS_TX_UUID      "6e400003-b5a3-f393-e0a9-e50e24dcca9e"  // device -> host (notify)

// WiFi STA control: TCP line server (same command grammar as serial).
#define WIFI_CONTROL_PORT 3333

#endif // CONFIG_H
