#include "RadioMode.h"

#include <cctype>

const char *radioModeToString(RadioMode m) {
  switch (m) {
    case RadioMode::Wifi: return "wifi";
    case RadioMode::Ble:  return "ble";
    case RadioMode::None:
    default:              return "none";
  }
}

bool radioModeFromString(const std::string &s, RadioMode &out) {
  std::string t;
  t.reserve(s.size());
  for (char c : s) t.push_back(static_cast<char>(std::tolower(static_cast<unsigned char>(c))));

  if (t == "none" || t == "off") { out = RadioMode::None; return true; }
  if (t == "wifi") { out = RadioMode::Wifi; return true; }
  if (t == "ble") { out = RadioMode::Ble; return true; }
  return false;
}
