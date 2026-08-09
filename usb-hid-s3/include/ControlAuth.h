#ifndef CONTROL_AUTH_H
#define CONTROL_AUTH_H

#include <string.h>
#include "Config.h"

/** True when CONTROL_API_TOKEN is non-empty at compile time. */
inline bool controlAuthRequired() {
  return CONTROL_API_TOKEN[0] != '\0';
}

inline bool controlTokenMatches(const char *provided) {
  if (!controlAuthRequired()) return true;
  if (!provided || provided[0] == '\0') return false;
  return strcmp(provided, CONTROL_API_TOKEN) == 0;
}

enum class ControlLineGate {
  Reject,    // drop; not authenticated
  Consumed,  // auth line handled; do not pass to command parser
  Accept     // pass to command parser
};

/**
 * Gate TCP/BLE control lines when CONTROL_API_TOKEN is set.
 * Clients authenticate once per session with: auth <token>
 */
inline ControlLineGate controlGateLine(const char *line, bool *authedInOut) {
  if (!controlAuthRequired()) {
    if (authedInOut) *authedInOut = true;
    return ControlLineGate::Accept;
  }
  if (!line || !authedInOut) return ControlLineGate::Reject;
  if (strncmp(line, "auth ", 5) == 0) {
    *authedInOut = controlTokenMatches(line + 5);
    return ControlLineGate::Consumed;
  }
  return *authedInOut ? ControlLineGate::Accept : ControlLineGate::Reject;
}

#endif  // CONTROL_AUTH_H
