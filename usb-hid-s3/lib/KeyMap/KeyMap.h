#ifndef KEY_MAP_H
#define KEY_MAP_H

// Pure, Arduino-free translation of a key name (e.g. "enter", "cmd+space",
// "ctrl+shift+t") into USB HID keyboard usage codes (Usage Page 0x07) plus a
// modifier bitmask. Unit-tested under env:native.

#include <cstdint>
#include <string>

// USB HID keyboard modifier bitmask (matches TinyUSB KEYBOARD_MODIFIER_*).
enum {
  KM_MOD_LCTRL  = 0x01,
  KM_MOD_LSHIFT = 0x02,
  KM_MOD_LALT   = 0x04,
  KM_MOD_LGUI   = 0x08,
};

struct KeyCode {
  bool found = false;
  uint8_t modifier = 0;  // OR of KM_MOD_*
  uint8_t keycode = 0;   // HID usage id (0 = none / modifier-only)
};

class KeyMap {
public:
  // Accepts a single key ("enter") or a combo ("cmd+space", "ctrl+shift+t").
  // Name is treated case-insensitively. Returns found=false if unrecognized.
  static KeyCode lookup(const std::string &name);

  // Look up just a base key token (no modifiers). Exposed for testing.
  static uint8_t baseKeycode(const std::string &token);
  // Look up a modifier token; returns 0 if not a modifier.
  static uint8_t modifierBit(const std::string &token);
};

#endif // KEY_MAP_H
