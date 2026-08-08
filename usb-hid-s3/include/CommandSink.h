#ifndef COMMAND_SINK_H
#define COMMAND_SINK_H

#include <stdint.h>
#include <string>

// Single entry point for a command line, regardless of transport
// (USB-CDC serial, BLE NUS, WiFi TCP, or HTTP REST). Defined in main.cpp.
// `source` is a short tag for logs, e.g. "serial", "ble", "wifi", "http".
void handleCommandLine(const std::string &line, const char *source);

// Status hooks for HTTP GET endpoints (implemented in main.cpp).
bool deviceJiggleEnabled();
uint32_t deviceJiggleIntervalMs();
bool deviceHidReady();

#endif // COMMAND_SINK_H
