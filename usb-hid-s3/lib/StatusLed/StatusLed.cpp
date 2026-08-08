#include "StatusLed.h"

#include <WiFi.h>
#include "esp32-hal-rgb-led.h"

#include "CommandSink.h"
#include "Config.h"
#include "RadioManager.h"

StatusLed g_statusLed;

void StatusLed::begin() {
  off();
}

void StatusLed::off() { show(0, 0, 0); }

void StatusLed::show(uint8_t r, uint8_t g, uint8_t b) {
  if (r == lastR_ && g == lastG_ && b == lastB_) return;
  lastR_ = r;
  lastG_ = g;
  lastB_ = b;
  // Waveshare ESP32-S3-Zero/Mini WS2812 is wired RGB (Arduino core default is
  // GRB, which swaps red↔green on this board — STA-idle green looked red).
  rgbLedWriteOrdered(STATUS_LED_PIN, LED_COLOR_ORDER_RGB, r, g, b);
}

void StatusLed::loop() {
  const uint8_t peak = STATUS_LED_BRIGHTNESS;
  const uint32_t now = millis();

  // 1) Soft-AP setup mode
  if (g_radio.mode() == RadioMode::Wifi && g_radio.isSoftAp()) {
    // Magenta slow blink ~1 Hz
    const bool on = ((now / 500) % 2) == 0;
    if (on) show(peak, 0, peak);
    else off();
    return;
  }

  // 2) WiFi not connected (radio off, BLE, STA connecting/failed)
  const bool staUp = (g_radio.mode() == RadioMode::Wifi && !g_radio.isSoftAp() &&
                      WiFi.status() == WL_CONNECTED);
  if (!staUp) {
    show(peak, 0, 0);  // solid red
    return;
  }

  // 3/4) STA connected — jiggle modulates pattern
  if (deviceJiggleEnabled()) {
    // Cyan breathing pulse
    const uint32_t period = 1200;
    uint32_t t = now % period;
    uint32_t half = period / 2;
    uint8_t level;
    if (t < half) level = (uint8_t)((t * peak) / half);
    else level = (uint8_t)(((period - t) * peak) / half);
    show(0, level, level);
  } else {
    // Dim solid green — healthy idle
    const uint8_t dim = peak / 3;
    show(0, dim > 0 ? dim : 1, 0);
  }
}
