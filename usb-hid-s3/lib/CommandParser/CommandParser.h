#ifndef COMMAND_PARSER_H
#define COMMAND_PARSER_H

// Pure, Arduino-free parsing of the serial command line.
// Unit-tested under env:native (see test/test_command_parser).

#include <string>

enum class CmdType {
  None,          // empty line
  Unknown,       // unrecognized / invalid
  Move,          // move dx dy [wheel]
  Click,         // click [left|right|middle]
  Type,          // type <text>
  Key,           // key <name[+name...]>
  JiggleOn,      // jiggle on
  JiggleOff,     // jiggle off
  JiggleStatus,  // jiggle | jiggle status
  Radio,         // radio wifi|ble|none
  WifiStatus,    // wifi | wifi status
  WifiSet,       // wifi set <ssid> <pass...>
  WifiClear,     // wifi clear
  Status,        // status
  Version,       // version
  Help,          // help
};

enum class MouseBtn { Left, Right, Middle };
enum class RadioSel { None, Wifi, Ble };

struct ParsedCommand {
  CmdType type = CmdType::None;

  // Move
  int dx = 0;
  int dy = 0;
  int wheel = 0;

  // Click
  MouseBtn button = MouseBtn::Left;

  // Type (verbatim, case + spaces preserved) / Key (name, lowercased)
  // WifiSet: text = ssid, text2 = password (may contain spaces)
  std::string text;
  std::string text2;

  // Radio
  RadioSel radio = RadioSel::None;

  // Populated when type == Unknown
  std::string error;
};

class CommandParser {
public:
  // Parse a single command line (no trailing newline required).
  static ParsedCommand parse(const std::string &line);
};

#endif // COMMAND_PARSER_H
