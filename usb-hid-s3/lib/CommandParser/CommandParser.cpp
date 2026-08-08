#include "CommandParser.h"

#include <cctype>
#include <cstdlib>
#include <vector>

namespace {

std::string trim(const std::string &s) {
  size_t a = 0;
  size_t b = s.size();
  while (a < b && std::isspace(static_cast<unsigned char>(s[a]))) a++;
  while (b > a && std::isspace(static_cast<unsigned char>(s[b - 1]))) b--;
  return s.substr(a, b - a);
}

std::string lower(std::string s) {
  for (char &c : s) c = static_cast<char>(std::tolower(static_cast<unsigned char>(c)));
  return s;
}

std::vector<std::string> split(const std::string &s) {
  std::vector<std::string> out;
  size_t i = 0;
  const size_t n = s.size();
  while (i < n) {
    while (i < n && std::isspace(static_cast<unsigned char>(s[i]))) i++;
    size_t start = i;
    while (i < n && !std::isspace(static_cast<unsigned char>(s[i]))) i++;
    if (i > start) out.push_back(s.substr(start, i - start));
  }
  return out;
}

// Strict integer parse: accepts optional +/- and digits only.
bool parseInt(const std::string &tok, int &out) {
  if (tok.empty()) return false;
  size_t i = 0;
  if (tok[i] == '+' || tok[i] == '-') i++;
  if (i >= tok.size()) return false;
  for (size_t j = i; j < tok.size(); j++) {
    if (!std::isdigit(static_cast<unsigned char>(tok[j]))) return false;
  }
  out = std::atoi(tok.c_str());
  return true;
}

ParsedCommand unknown(const std::string &why) {
  ParsedCommand c;
  c.type = CmdType::Unknown;
  c.error = why;
  return c;
}

}  // namespace

ParsedCommand CommandParser::parse(const std::string &rawLine) {
  const std::string line = trim(rawLine);
  if (line.empty()) {
    ParsedCommand c;
    c.type = CmdType::None;
    return c;
  }

  const std::vector<std::string> tok = split(line);
  const std::string cmd = lower(tok[0]);

  if (cmd == "move") {
    if (tok.size() < 3) return unknown("move needs <dx> <dy> [wheel]");
    ParsedCommand c;
    c.type = CmdType::Move;
    if (!parseInt(tok[1], c.dx) || !parseInt(tok[2], c.dy))
      return unknown("move deltas must be integers");
    if (tok.size() >= 4 && !parseInt(tok[3], c.wheel))
      return unknown("wheel must be an integer");
    return c;
  }

  if (cmd == "click") {
    ParsedCommand c;
    c.type = CmdType::Click;
    if (tok.size() >= 2) {
      const std::string b = lower(tok[1]);
      if (b == "left") c.button = MouseBtn::Left;
      else if (b == "right") c.button = MouseBtn::Right;
      else if (b == "middle") c.button = MouseBtn::Middle;
      else return unknown("click button must be left|right|middle");
    }
    return c;
  }

  if (cmd == "type") {
    // Preserve everything after the first token verbatim (case + spaces).
    ParsedCommand c;
    c.type = CmdType::Type;
    size_t pos = line.find_first_of(" \t");
    if (pos == std::string::npos) return unknown("type needs text");
    std::string rest = line.substr(pos + 1);
    // Only trim a single leading run of spaces, keep the rest verbatim.
    size_t s = 0;
    while (s < rest.size() && (rest[s] == ' ' || rest[s] == '\t')) s++;
    rest = rest.substr(s);
    if (rest.empty()) return unknown("type needs text");
    c.text = rest;
    return c;
  }

  if (cmd == "key") {
    if (tok.size() < 2) return unknown("key needs a name (e.g. enter, cmd+space)");
    ParsedCommand c;
    c.type = CmdType::Key;
    c.text = lower(tok[1]);
    return c;
  }

  if (cmd == "jiggle") {
    if (tok.size() < 2) {
      ParsedCommand c;
      c.type = CmdType::JiggleStatus;
      return c;
    }
    const std::string sub = lower(tok[1]);
    ParsedCommand c;
    if (sub == "on") c.type = CmdType::JiggleOn;
    else if (sub == "off") c.type = CmdType::JiggleOff;
    else if (sub == "status") c.type = CmdType::JiggleStatus;
    else return unknown("jiggle needs on|off|status");
    return c;
  }

  if (cmd == "radio") {
    if (tok.size() < 2) return unknown("radio needs wifi|ble|none");
    const std::string sub = lower(tok[1]);
    ParsedCommand c;
    c.type = CmdType::Radio;
    if (sub == "wifi") c.radio = RadioSel::Wifi;
    else if (sub == "ble") c.radio = RadioSel::Ble;
    else if (sub == "none" || sub == "off") c.radio = RadioSel::None;
    else return unknown("radio needs wifi|ble|none");
    return c;
  }

  if (cmd == "wifi") {
    if (tok.size() < 2 || lower(tok[1]) == "status") {
      ParsedCommand c;
      c.type = CmdType::WifiStatus;
      return c;
    }
    const std::string sub = lower(tok[1]);
    if (sub == "clear") {
      ParsedCommand c;
      c.type = CmdType::WifiClear;
      return c;
    }
    if (sub == "set") {
      // wifi set <ssid> [<password...>] — password is the remainder after ssid
      // (may be empty for an open network).
      if (tok.size() < 3) return unknown("wifi set needs <ssid> [password]");
      ParsedCommand c;
      c.type = CmdType::WifiSet;
      c.text = tok[2];  // ssid (no spaces)
      // Password: everything after the ssid token in the original line.
      size_t p = 0;
      // skip "wifi"
      while (p < line.size() && !std::isspace(static_cast<unsigned char>(line[p]))) p++;
      while (p < line.size() && std::isspace(static_cast<unsigned char>(line[p]))) p++;
      // skip "set"
      while (p < line.size() && !std::isspace(static_cast<unsigned char>(line[p]))) p++;
      while (p < line.size() && std::isspace(static_cast<unsigned char>(line[p]))) p++;
      // skip ssid
      while (p < line.size() && !std::isspace(static_cast<unsigned char>(line[p]))) p++;
      while (p < line.size() && std::isspace(static_cast<unsigned char>(line[p]))) p++;
      c.text2 = line.substr(p);  // may be empty (open network)
      return c;
    }
    return unknown("wifi needs status|set|clear");
  }

  if (cmd == "status") {
    ParsedCommand c;
    c.type = CmdType::Status;
    return c;
  }
  if (cmd == "version") {
    ParsedCommand c;
    c.type = CmdType::Version;
    return c;
  }
  if (cmd == "help" || cmd == "?") {
    ParsedCommand c;
    c.type = CmdType::Help;
    return c;
  }

  return unknown("unknown command: " + cmd);
}
