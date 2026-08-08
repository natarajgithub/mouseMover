#ifndef WIFI_CONFIG_SERVER_H
#define WIFI_CONFIG_SERVER_H

#include <Arduino.h>

/**
 * HTTP REST API (port WIFI_HTTP_PORT, typically 80).
 *
 * Runs on Soft-AP (setup) and on STA (LAN control).
 *
 * WiFi provisioning (Soft-AP / reconfig):
 *   GET  /                 HTML setup form (Soft-AP) or API index (STA)
 *   GET  /api/wifi         WiFi status JSON
 *   POST /api/wifi         {"ssid","password"} → NVS save + reconnect
 *   POST /api/wifi/clear   clear NVS creds
 *
 * Device control (same command sink as serial/TCP):
 *   GET  /api/status       device status JSON
 *   GET  /api/jiggle       {"enabled", "interval_ms"}
 *   POST /api/jiggle       {"enabled": true|false}
 *   POST /api/move         {"dx", "dy", "wheel"?}
 *   POST /api/type         {"text": "..."}
 *   POST /api/key          {"key": "enter"}  (or "name")
 *   POST /api/click        {"button": "left"|"right"|"middle"}
 *
 * CORS enabled for future mobile apps. After POST /api/wifi, call
 * takeReconnectRequest() from RadioManager::loop().
 */

class WifiConfigServer {
public:
  void begin();
  void stop();
  void loop();

  bool isRunning() const { return running_; }

  bool takeReconnectRequest();
  void requestReconnect();

private:
  void handleCors();
  void handleOptions();
  void handleRoot();
  void handleGetWifi();
  void handlePostWifi();
  void handleClearWifi();
  void handleGetStatus();
  void handleGetJiggle();
  void handlePostJiggle();
  void handlePostMove();
  void handlePostType();
  void handlePostKey();
  void handlePostClick();
  void sendOk(const String &extraJson = "");
  void sendErr(int code, const char *error);

  bool running_ = false;
  bool reconnectPending_ = false;
};

extern WifiConfigServer g_wifiConfig;

#endif  // WIFI_CONFIG_SERVER_H
