#ifndef RADIO_MODE_H
#define RADIO_MODE_H

// Pure, Arduino-free radio-mode selection. Exactly one radio is ever active.
// The actual WiFi/BLE stack wiring lands in Phase 3; this is the shared type +
// string mapping used by config, serial commands, and status.

#include <string>

enum class RadioMode {
  None,  // no radio active
  Wifi,  // WiFi STA active, BLE off
  Ble,   // BLE active, WiFi off
};

const char *radioModeToString(RadioMode m);

// Parse "none"/"off", "wifi", "ble" (case-insensitive). Returns false if
// unrecognized; *out is left unchanged.
bool radioModeFromString(const std::string &s, RadioMode &out);

#endif // RADIO_MODE_H
