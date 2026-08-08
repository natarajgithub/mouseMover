#ifndef RADIO_MANAGER_H
#define RADIO_MANAGER_H

// Mutually-exclusive WiFi *or* BLE, plus a remote control transport that feeds
// command lines into the same handler as the serial interface.
//
// WiFi path:
//   - STA credentials in NVS (WifiCredentials). If none → Soft-AP setup portal
//     (WIFI_AP_SSID) + HTTP REST on :80 for app/browser provisioning.
//   - If credentials exist → STA + TCP line control on WIFI_CONTROL_PORT.
//
// Only one radio is ever active at a time (single 2.4 GHz radio). USB HID is a
// separate peripheral and is unaffected.

#include <Arduino.h>

#include "RadioMode.h"

class RadioManager {
public:
  void begin(RadioMode initial);

  // Switch the active radio. Tears down the current stack first.
  bool setMode(RadioMode m);

  RadioMode mode() const { return mode_; }

  // Must be called from loop() (TCP client + Soft-AP HTTP + reconnect).
  void loop();

  // Short human-readable status, e.g. "none", "ble:adv", "wifi:1.2.3.4", "wifi:ap".
  const char *statusStr();

  // Push a line back to the connected control client (BLE notify / TCP write).
  void sendToControl(const char *line);

  // Apply newly saved STA credentials (from serial `wifi set` or Soft-AP REST).
  // If currently in Wifi mode, restarts WiFi to Soft-AP or STA as appropriate.
  void applyWifiCredentials();

  // True while Soft-AP setup portal is up.
  bool isSoftAp() const { return softAp_; }

private:
  void startWifi();
  void stopWifi();
  void startBle();
  void stopBle();
  void startSoftAp();
  void startSta(const String &ssid, const String &pass);

  RadioMode mode_ = RadioMode::None;
  bool softAp_ = false;
  char status_[64] = "none";
};

extern RadioManager g_radio;

#endif // RADIO_MANAGER_H
