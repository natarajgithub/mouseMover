// USB HID Mouse+Keyboard on ESP32-S3 (ESP32 core native USB: USBCDC + USBHID).
//
// Composite device: USB-CDC serial (logging + command interface) plus a HID
// keyboard (report id 1) and mouse (report id 2), driven by the ESP32 core's
// native USB stack. The Adafruit TinyUSB stack was dropped because, combined
// with the core USBCDC, its re-enumeration left the CDC OUT endpoint (serial
// RX) non-functional; the core stack integrates CDC RX+TX and HID cleanly.
//
// Serial commands (move/click/type/key/jiggle/radio/...) plus a FreeRTOS jiggle
// task. The `radio` command activates the WiFi/BLE stack (mutually exclusive).

#include <Arduino.h>
#include "USB.h"
#include "USBHIDMouse.h"
#include "USBHIDKeyboard.h"

#include "Config.h"
#include "Logging.h"

#include "CommandParser.h"
#include "CommandSink.h"
#include "JiggleEngine.h"
#include "KeyMap.h"
#include "RadioMode.h"
#include "RadioManager.h"
#include "StatusLed.h"
#include "WifiCredentials.h"

// ---------------------------------------------------------------------------
// USB devices (core stack). ARDUINO_USB_CDC_ON_BOOT=0, so the core does NOT
// auto-start USB at boot; we register identity + HID + CDC here and call
// USB.begin() exactly once (ESPUSB::begin() only inits TinyUSB on the first
// call, so everything must be registered before it).
//
// UsbSerial is our USB-CDC (replaces the boot `Serial`); Logging.h logs to it.
// ---------------------------------------------------------------------------
USBCDC UsbSerial(0);
static USBHIDMouse Mouse;
static USBHIDKeyboard Keyboard;
static USBHID g_hid;  // standalone handle used only for ready() (global HID state)

// ---------------------------------------------------------------------------
// Shared state
// ---------------------------------------------------------------------------
static JiggleEngine g_jiggle(JIGGLE_MAX_DELTA, JIGGLE_INTERVAL_MS);
static SemaphoreHandle_t g_hidMutex = nullptr;

static char g_cmdBuf[SERIAL_CMD_MAXLEN];
static size_t g_cmdLen = 0;
static uint32_t g_lastHeartbeatMs = 0;
static const uint32_t HEARTBEAT_MS = 10000;

// ---------------------------------------------------------------------------
// HID helpers (all serialized via g_hidMutex; safe from task + loop)
// ---------------------------------------------------------------------------
static bool hidReady() {
  return g_hid.ready();
}

static bool lockHid(uint32_t waitMs = 500) {
  if (!g_hidMutex) return false;
  return xSemaphoreTake(g_hidMutex, pdMS_TO_TICKS(waitMs)) == pdTRUE;
}
static void unlockHid() {
  if (g_hidMutex) xSemaphoreGive(g_hidMutex);
}

static int8_t clamp8(int v) {
  if (v > 127) return 127;
  if (v < -127) return -127;
  return (int8_t)v;
}

// Move the mouse by (dx,dy) pixels and scroll `wheel`, chunked into int8 steps.
static bool hidMouseMove(int dx, int dy, int wheel) {
  if (!hidReady()) {
    LOG_HID("mouse move skipped: not-ready");
    return false;
  }
  if (!lockHid()) return false;
  int rx = dx, ry = dy, rw = wheel;
  do {
    int8_t sx = clamp8(rx);
    int8_t sy = clamp8(ry);
    int8_t sw = clamp8(rw);
    Mouse.move(sx, sy, sw);
    rx -= sx;
    ry -= sy;
    rw -= sw;
    if (rx || ry || rw) delay(2);
  } while (rx || ry || rw);
  unlockHid();
  return true;
}

static uint8_t buttonMask(MouseBtn b) {
  switch (b) {
    case MouseBtn::Right: return MOUSE_RIGHT;
    case MouseBtn::Middle: return MOUSE_MIDDLE;
    case MouseBtn::Left:
    default: return MOUSE_LEFT;
  }
}

static bool hidClick(MouseBtn b) {
  if (!hidReady()) {
    LOG_HID("click skipped: not-ready");
    return false;
  }
  if (!lockHid()) return false;
  const uint8_t mask = buttonMask(b);
  Mouse.press(mask);
  delay(15);
  Mouse.release(mask);
  unlockHid();
  return true;
}

static bool hidType(const std::string &text) {
  if (!hidReady()) {
    LOG_HID("type skipped: not-ready");
    return false;
  }
  if (!lockHid(1500)) return false;
  for (char ch : text) {
    Keyboard.write((uint8_t)ch);
    delay(8);
  }
  unlockHid();
  return true;
}

static bool hidKey(const KeyCode &kc) {
  if (!hidReady()) {
    LOG_HID("key skipped: not-ready");
    return false;
  }
  if (!lockHid()) return false;
  KeyReport report = {};
  report.modifiers = kc.modifier;
  report.keys[0] = kc.keycode;  // raw HID usage code from KeyMap
  Keyboard.sendReport(&report);
  delay(15);
  KeyReport empty = {};
  Keyboard.sendReport(&empty);
  unlockHid();
  return true;
}

// ---------------------------------------------------------------------------
// Serial command dispatch
// ---------------------------------------------------------------------------
static void printHelp() {
  LOG_INFO("commands:");
  LOG_INFO("  move <dx> <dy> [wheel]   move mouse (relative)");
  LOG_INFO("  click [left|right|middle]");
  LOG_INFO("  type <text>              type a string");
  LOG_INFO("  key <name[+name...]>     press a key/combo (enter,esc,cmd+space,...)");
  LOG_INFO("  jiggle on|off|status");
  LOG_INFO("  radio wifi|ble|none      activate exactly one radio (or none)");
  LOG_INFO("  wifi status|set|clear    NVS WiFi creds (Soft-AP if none)");
  LOG_INFO("  status | version | help");
}

static void printStatus() {
  LOG_INFO("status version=%s uptime=%lus heap=%u usb=%s jiggle=%s interval=%lums radio=%s",
           FW_VERSION, (unsigned long)(millis() / 1000), (unsigned)ESP.getFreeHeap(),
           hidReady() ? "ready" : "not-ready",
           g_jiggle.isEnabled() ? "on" : "off",
           (unsigned long)g_jiggle.intervalMs(),
           g_radio.statusStr());
}

bool deviceJiggleEnabled() { return g_jiggle.isEnabled(); }
uint32_t deviceJiggleIntervalMs() { return g_jiggle.intervalMs(); }
bool deviceHidReady() { return hidReady(); }

void handleCommandLine(const std::string &line, const char *source) {
  ParsedCommand c = CommandParser::parse(line);
  if (c.type != CmdType::None)
    LOG_CMD_DEBUG("src=%s line=\"%s\"", source ? source : "?", line.c_str());
  switch (c.type) {
    case CmdType::None:
      break;
    case CmdType::Move:
      LOG_CMD("move dx=%d dy=%d wheel=%d", c.dx, c.dy, c.wheel);
      if (hidMouseMove(c.dx, c.dy, c.wheel))
        LOG_HID("move ok dx=%d dy=%d wheel=%d", c.dx, c.dy, c.wheel);
      break;
    case CmdType::Click:
      LOG_CMD("click %d", (int)c.button);
      if (hidClick(c.button)) LOG_HID("click ok");
      break;
    case CmdType::Type:
      LOG_CMD("type len=%u", (unsigned)c.text.size());
      if (hidType(c.text)) LOG_HID("type ok len=%u", (unsigned)c.text.size());
      break;
    case CmdType::Key: {
      KeyCode kc = KeyMap::lookup(c.text);
      if (!kc.found) {
        LOG_WARN("key unknown: %s", c.text.c_str());
        break;
      }
      LOG_CMD("key %s mod=0x%02x kc=0x%02x", c.text.c_str(), kc.modifier, kc.keycode);
      if (hidKey(kc)) LOG_HID("key ok %s", c.text.c_str());
      break;
    }
    case CmdType::JiggleOn:
      g_jiggle.setEnabled(true);
      LOG_JIG("jiggle=on interval=%lums", (unsigned long)g_jiggle.intervalMs());
      break;
    case CmdType::JiggleOff:
      g_jiggle.setEnabled(false);
      LOG_JIG("jiggle=off");
      break;
    case CmdType::JiggleStatus:
      LOG_JIG("jiggle=%s interval=%lums", g_jiggle.isEnabled() ? "on" : "off",
              (unsigned long)g_jiggle.intervalMs());
      break;
    case CmdType::Radio: {
      RadioMode target = RadioMode::None;
      switch (c.radio) {
        case RadioSel::Wifi: target = RadioMode::Wifi; break;
        case RadioSel::Ble: target = RadioMode::Ble; break;
        case RadioSel::None: default: target = RadioMode::None; break;
      }
      g_radio.setMode(target);
      LOG_RADIO("radio=%s status=%s", radioModeToString(g_radio.mode()),
                g_radio.statusStr());
      break;
    }
    case CmdType::WifiStatus: {
      WifiCreds wc = WifiCredentials::get();
      LOG_WIFI("wifi configured=%s ssid=\"%s\" pass_len=%u soft_ap=%s radio=%s",
               WifiCredentials::hasSsid() ? "yes" : "no",
               wc.ssid.c_str(), (unsigned)wc.pass.length(),
               g_radio.isSoftAp() ? "yes" : "no",
               g_radio.statusStr());
      break;
    }
    case CmdType::WifiSet: {
      if (!WifiCredentials::save(String(c.text.c_str()), String(c.text2.c_str()))) {
        LOG_WARN("wifi set failed");
        break;
      }
      LOG_WIFI("wifi set ok ssid=\"%s\"", c.text.c_str());
      g_radio.applyWifiCredentials();
      break;
    }
    case CmdType::WifiClear: {
      WifiCredentials::clear();
      LOG_WIFI("wifi clear ok");
      g_radio.applyWifiCredentials();
      break;
    }
    case CmdType::Status:
      printStatus();
      break;
    case CmdType::Version:
      LOG_INFO("version=%s name=%s", FW_VERSION, FW_NAME);
      break;
    case CmdType::Help:
      printHelp();
      break;
    case CmdType::Unknown:
    default:
      LOG_WARN("cmd error: %s", c.error.c_str());
      break;
  }
}

static void serviceSerialCommands() {
  while (UsbSerial.available()) {
    char ch = (char)UsbSerial.read();
    if (ch == '\r') continue;
    if (ch == '\n') {
      g_cmdBuf[g_cmdLen] = '\0';
      if (g_cmdLen > 0) handleCommandLine(std::string(g_cmdBuf), "serial");
      g_cmdLen = 0;
    } else if (g_cmdLen < SERIAL_CMD_MAXLEN - 1) {
      g_cmdBuf[g_cmdLen++] = ch;
    }
  }
}

// ---------------------------------------------------------------------------
// Jiggle task
// ---------------------------------------------------------------------------
static void jiggleTask(void *) {
  for (;;) {
    int dx = 0, dy = 0;
    if (g_jiggle.update(millis(), dx, dy)) {
      if (hidMouseMove(dx, dy, 0)) LOG_JIG("auto dx=%d dy=%d", dx, dy);
    }
    vTaskDelay(pdMS_TO_TICKS(50));
  }
}

// ---------------------------------------------------------------------------
// Boot diagnostics
// ---------------------------------------------------------------------------
static void printBanner() {
  LOG_INFO("=== %s v%s (core USB: CDC + HID mouse+keyboard) ===", FW_NAME, FW_VERSION);
  LOG_INFO("chip=%s rev=%d cores=%d cpu=%dMHz", ESP.getChipModel(),
           ESP.getChipRevision(), ESP.getChipCores(), (int)ESP.getCpuFreqMHz());
  LOG_INFO("flash=%u bytes heap=%u min_heap=%u", (unsigned)ESP.getFlashChipSize(),
           (unsigned)ESP.getFreeHeap(), (unsigned)ESP.getMinFreeHeap());
  LOG_USB("vid=0x%04X pid=0x%04X product=\"%s\"", HID_USB_VID, HID_USB_PID, HID_USB_PRODUCT);
  LOG_INFO("boot-ok");
}

// ---------------------------------------------------------------------------
void setup() {
  g_hidMutex = xSemaphoreCreateMutex();

  // Full USB bring-up, in order, BEFORE the single USB.begin():
  //   1) identity (VID/PID/strings)  2) HID devices  3) CDC  4) USB.begin()
  // ESPUSB::begin() runs tinyusb_init only once, so anything registered after
  // it is ignored. ARDUINO_USB_CDC_ON_BOOT=0 guarantees no boot-time begin().
  USB.VID(HID_USB_VID);
  USB.PID(HID_USB_PID);
  USB.productName(HID_USB_PRODUCT);
  USB.manufacturerName(HID_USB_MANUFACTURER);
  USB.firmwareVersion(FW_VERSION_BCD);

  Mouse.begin();
  Keyboard.begin();
  UsbSerial.begin(SERIAL_BAUD);
  USB.begin();

  uint32_t start = millis();
  while (!UsbSerial && (millis() - start) < 2000) delay(10);
  delay(200);

  printBanner();

  g_statusLed.begin();

#if JIGGLE_ENABLED_DEFAULT
  g_jiggle.setEnabled(true);
#endif

  xTaskCreatePinnedToCore(jiggleTask, "jiggle", 4096, nullptr, 1, nullptr, 0);

  // NVS WiFi creds (seed from compile-time WIFI_SSID on first boot).
  WifiCredentials::begin();

  // Bring up the default radio (compile-time selectable; runtime via `radio`).
  RadioMode initial = RadioMode::None;
  radioModeFromString(RADIO_MODE_DEFAULT_STR, initial);
  g_radio.begin(initial);
  LOG_RADIO("default mode=%s status=%s", radioModeToString(g_radio.mode()),
            g_radio.statusStr());

  LOG_INFO("ready: type 'help' for commands");
}

void loop() {
  serviceSerialCommands();
  g_radio.loop();
  g_statusLed.loop();

  const uint32_t now = millis();
  if (now - g_lastHeartbeatMs >= HEARTBEAT_MS) {
    g_lastHeartbeatMs = now;
    LOG_INFO("heartbeat uptime=%lus heap=%u usb=%s jiggle=%s radio=%s",
             (unsigned long)(now / 1000), (unsigned)ESP.getFreeHeap(),
             hidReady() ? "ready" : "not-ready", g_jiggle.isEnabled() ? "on" : "off",
             g_radio.statusStr());
  }
  delay(2);
}
