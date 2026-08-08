#ifndef STATUS_LED_H
#define STATUS_LED_H

#include <Arduino.h>

/**
 * Onboard WS2812 status LED (Waveshare ESP32-S3 Mini/Zero, GPIO21).
 *
 * Priority (highest first):
 *   1) Soft-AP setup     → magenta, slow blink
 *   2) WiFi disconnected → red, solid
 *   3) STA + jiggle on   → cyan, breathing pulse
 *   4) STA + jiggle off  → green, solid dim
 */

class StatusLed {
public:
  void begin();
  // Call from loop(); reads radio/jiggle state and drives the LED.
  void loop();

private:
  void show(uint8_t r, uint8_t g, uint8_t b);
  void off();

  uint8_t lastR_ = 255, lastG_ = 255, lastB_ = 255;
};

extern StatusLed g_statusLed;

#endif  // STATUS_LED_H
