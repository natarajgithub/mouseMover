#include "KeyMap.h"

#include <cctype>
#include <vector>

namespace {

std::string lower(std::string s) {
  for (char &c : s) c = static_cast<char>(std::tolower(static_cast<unsigned char>(c)));
  return s;
}

std::vector<std::string> splitPlus(const std::string &s) {
  std::vector<std::string> out;
  std::string cur;
  for (char c : s) {
    if (c == '+') {
      if (!cur.empty()) out.push_back(cur);
      cur.clear();
    } else {
      cur.push_back(c);
    }
  }
  if (!cur.empty()) out.push_back(cur);
  return out;
}

}  // namespace

uint8_t KeyMap::modifierBit(const std::string &tokenRaw) {
  const std::string t = lower(tokenRaw);
  if (t == "ctrl" || t == "control") return KM_MOD_LCTRL;
  if (t == "shift") return KM_MOD_LSHIFT;
  if (t == "alt" || t == "opt" || t == "option") return KM_MOD_LALT;
  if (t == "cmd" || t == "command" || t == "gui" || t == "win" ||
      t == "super" || t == "meta")
    return KM_MOD_LGUI;
  return 0;
}

uint8_t KeyMap::baseKeycode(const std::string &tokenRaw) {
  const std::string t = lower(tokenRaw);

  // Single letter a-z -> 0x04..0x1D
  if (t.size() == 1) {
    const char c = t[0];
    if (c >= 'a' && c <= 'z') return static_cast<uint8_t>(0x04 + (c - 'a'));
    if (c >= '1' && c <= '9') return static_cast<uint8_t>(0x1E + (c - '1'));
    if (c == '0') return 0x27;
    if (c == ' ') return 0x2C;
    if (c == '-') return 0x2D;
    if (c == '=') return 0x2E;
    if (c == '[') return 0x2F;
    if (c == ']') return 0x30;
    if (c == '\\') return 0x31;
    if (c == ';') return 0x33;
    if (c == '\'') return 0x34;
    if (c == '`') return 0x35;
    if (c == ',') return 0x36;
    if (c == '.') return 0x37;
    if (c == '/') return 0x38;
  }

  if (t == "enter" || t == "return") return 0x28;
  if (t == "esc" || t == "escape") return 0x29;
  if (t == "backspace" || t == "bksp") return 0x2A;
  if (t == "tab") return 0x2B;
  if (t == "space" || t == "spacebar") return 0x2C;
  if (t == "delete" || t == "del") return 0x4C;      // forward delete
  if (t == "insert" || t == "ins") return 0x49;
  if (t == "home") return 0x4A;
  if (t == "end") return 0x4D;
  if (t == "pageup" || t == "pgup") return 0x4B;
  if (t == "pagedown" || t == "pgdn") return 0x4E;
  if (t == "right" || t == "rightarrow") return 0x4F;
  if (t == "left" || t == "leftarrow") return 0x50;
  if (t == "down" || t == "downarrow") return 0x51;
  if (t == "up" || t == "uparrow") return 0x52;
  if (t == "capslock" || t == "caps") return 0x39;
  if (t == "printscreen" || t == "prtsc") return 0x46;

  // Function keys F1..F12 -> 0x3A..0x45
  if (t.size() >= 2 && t[0] == 'f') {
    bool digits = true;
    for (size_t i = 1; i < t.size(); i++) {
      if (!std::isdigit(static_cast<unsigned char>(t[i]))) { digits = false; break; }
    }
    if (digits) {
      const int n = std::atoi(t.c_str() + 1);
      if (n >= 1 && n <= 12) return static_cast<uint8_t>(0x3A + (n - 1));
    }
  }

  return 0;  // not found
}

KeyCode KeyMap::lookup(const std::string &name) {
  KeyCode out;
  const std::vector<std::string> parts = splitPlus(name);
  if (parts.empty()) return out;

  // Every part except the last must be a modifier; the last is the base key.
  // (Allow the last to also be a bare modifier, e.g. "cmd" -> modifier only.)
  for (size_t i = 0; i + 1 < parts.size(); i++) {
    const uint8_t m = modifierBit(parts[i]);
    if (m == 0) return out;  // invalid combo
    out.modifier |= m;
  }

  const std::string &last = parts.back();
  const uint8_t base = baseKeycode(last);
  if (base != 0) {
    out.keycode = base;
    out.found = true;
    return out;
  }

  // Last token might itself be a modifier (modifier-only combo).
  const uint8_t m = modifierBit(last);
  if (m != 0) {
    out.modifier |= m;
    out.found = true;  // modifier-only press is valid
    return out;
  }

  out.found = false;
  return out;
}
