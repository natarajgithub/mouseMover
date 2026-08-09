#include "RadioManager.h"

#include <WiFi.h>
#include <WiFiServer.h>
#include <WiFiClient.h>
#include <ESPmDNS.h>

#include <NimBLEDevice.h>

#include "Config.h"
#include "ControlAuth.h"
#include "CommandSink.h"
#include "Logging.h"
#include "WifiCredentials.h"
#include "WifiConfigServer.h"

RadioManager g_radio;

// ---------------------------------------------------------------------------
// BLE (Nordic UART Service) control transport
// ---------------------------------------------------------------------------
namespace {

NimBLEServer *s_bleServer = nullptr;
NimBLECharacteristic *s_bleTx = nullptr;
volatile bool s_bleConnected = false;
// Set while stopBle() is releasing the stack so the disconnect callback does
// NOT restart advertising mid-teardown (which crashes deinit(true)).
volatile bool s_bleTearingDown = false;

bool s_bleAuthed = false;
bool s_tcpAuthed = false;

void dispatchControlLine(const std::string &line, const char *source,
                         bool *authed) {
  const ControlLineGate gate = controlGateLine(line.c_str(), authed);
  if (gate == ControlLineGate::Reject) {
    LOG_INFO("control auth rejected src=%s", source);
    return;
  }
  if (gate == ControlLineGate::Consumed) {
    LOG_INFO("control auth %s src=%s", *authed ? "ok" : "failed", source);
    return;
  }
  handleCommandLine(line, source);
}

// Split incoming bytes into lines and dispatch each.
void feedControlLines(std::string &buf, const std::string &incoming,
                      const char *source, bool *authed) {
  buf += incoming;
  size_t nl;
  while ((nl = buf.find('\n')) != std::string::npos) {
    std::string line = buf.substr(0, nl);
    buf.erase(0, nl + 1);
    if (!line.empty() && line.back() == '\r') line.pop_back();
    if (!line.empty()) dispatchControlLine(line, source, authed);
  }
}

std::string s_bleLineBuf;

class RxCallbacks : public NimBLECharacteristicCallbacks {
  void onWrite(NimBLECharacteristic *c, NimBLEConnInfo &) override {
    std::string v = c->getValue();
    if (v.empty()) return;
    // BLE writes may or may not include a trailing newline; treat a write
    // without a newline as a complete line too.
    if (v.find('\n') == std::string::npos) {
      std::string line = v;
      if (!line.empty() && line.back() == '\r') line.pop_back();
      dispatchControlLine(line, "ble", &s_bleAuthed);
    } else {
      feedControlLines(s_bleLineBuf, v, "ble", &s_bleAuthed);
    }
  }
};

class ServerCallbacks : public NimBLEServerCallbacks {
  void onConnect(NimBLEServer *, NimBLEConnInfo &) override {
    s_bleConnected = true;
    s_bleAuthed = !controlAuthRequired();
    LOG_BLE("central connected");
  }
  void onDisconnect(NimBLEServer *, NimBLEConnInfo &, int reason) override {
    s_bleConnected = false;
    s_bleAuthed = false;
    if (s_bleTearingDown) {
      LOG_BLE("central disconnected reason=%d during teardown", reason);
      return;
    }
    LOG_BLE("central disconnected reason=%d; re-advertising", reason);
    NimBLEDevice::startAdvertising();
  }
};

RxCallbacks s_rxCallbacks;
ServerCallbacks s_serverCallbacks;

// WiFi TCP line server
WiFiServer s_tcpServer(WIFI_CONTROL_PORT);
WiFiClient s_tcpClient;
std::string s_tcpLineBuf;

}  // namespace

// ---------------------------------------------------------------------------
void RadioManager::begin(RadioMode initial) {
  mode_ = RadioMode::None;
  snprintf(status_, sizeof(status_), "none");
  if (initial != RadioMode::None) setMode(initial);
}

bool RadioManager::setMode(RadioMode m) {
  if (m == mode_) return true;

  // Tear down whatever is active.
  if (mode_ == RadioMode::Wifi) stopWifi();
  else if (mode_ == RadioMode::Ble) stopBle();

  mode_ = m;
  switch (m) {
    case RadioMode::Wifi: startWifi(); break;
    case RadioMode::Ble: startBle(); break;
    case RadioMode::None:
    default: snprintf(status_, sizeof(status_), "none"); break;
  }
  LOG_RADIO("mode=%s status=%s", radioModeToString(mode_), status_);
  return true;
}

// ---------------------------------------------------------------------------
// WiFi (STA with NVS creds, or Soft-AP setup portal)
// ---------------------------------------------------------------------------
void RadioManager::startSoftAp() {
  softAp_ = true;
  WiFi.mode(WIFI_AP);
  const bool openAp = (WIFI_AP_PASS[0] == '\0');
  bool ok = openAp
                ? WiFi.softAP(WIFI_AP_SSID, nullptr, WIFI_AP_CHANNEL)
                : WiFi.softAP(WIFI_AP_SSID, WIFI_AP_PASS, WIFI_AP_CHANNEL);
  if (!ok) {
    snprintf(status_, sizeof(status_), "wifi:ap-fail");
    LOG_WIFI("Soft-AP start failed");
    return;
  }
  delay(100);
  IPAddress ip = WiFi.softAPIP();
  snprintf(status_, sizeof(status_), "wifi:ap");
  LOG_WIFI("soft-ap ssid=\"%s\" ip=%s http=:%d (configure via REST /api/wifi)",
           WIFI_AP_SSID, ip.toString().c_str(), WIFI_HTTP_PORT);
  g_wifiConfig.begin();
}

void RadioManager::startSta(const String &ssid, const String &pass) {
  softAp_ = false;
  WiFi.mode(WIFI_STA);
  WiFi.begin(ssid.c_str(), pass.c_str());
  LOG_WIFI("connecting to %s ...", ssid.c_str());
  uint32_t start = millis();
  while (WiFi.status() != WL_CONNECTED &&
         (millis() - start) < WIFI_CONNECT_TIMEOUT_MS) {
    delay(200);
  }
  if (WiFi.status() == WL_CONNECTED) {
    s_tcpServer.begin();
    s_tcpServer.setNoDelay(true);
    g_wifiConfig.begin();  // STA REST control API on :80
    if (MDNS.begin(MDNS_HOSTNAME)) {
      MDNS.addService("http", "tcp", WIFI_HTTP_PORT);
      MDNS.addServiceTxt("http", "tcp", "path", "/api/status");
      LOG_WIFI("mDNS started as %s.local (http :%d)", MDNS_HOSTNAME, WIFI_HTTP_PORT);
    } else {
      LOG_WIFI("mDNS start failed");
    }
    snprintf(status_, sizeof(status_), "wifi:%s", WiFi.localIP().toString().c_str());
    LOG_WIFI("connected ip=%s control-port=%d http=:%d mdns=%s.local",
             WiFi.localIP().toString().c_str(), WIFI_CONTROL_PORT, WIFI_HTTP_PORT,
             MDNS_HOSTNAME);
  } else {
    LOG_WIFI("connect timeout; falling back to Soft-AP setup");
    WiFi.disconnect(true);
    startSoftAp();
  }
}

void RadioManager::startWifi() {
  WifiCreds c = WifiCredentials::get();
  if (c.ssid.length() == 0) {
    LOG_WIFI("no STA credentials in NVS; starting Soft-AP setup");
    startSoftAp();
    return;
  }
  startSta(c.ssid, c.pass);
}

void RadioManager::stopWifi() {
  MDNS.end();
  g_wifiConfig.stop();
  softAp_ = false;
  s_tcpClient.stop();
  s_tcpServer.stop();
  s_tcpLineBuf.clear();
  WiFi.softAPdisconnect(true);
  WiFi.disconnect(true);
  WiFi.mode(WIFI_OFF);
  LOG_WIFI("stopped");
}

void RadioManager::applyWifiCredentials() {
  if (mode_ != RadioMode::Wifi) {
    LOG_WIFI("credentials updated (will apply on next radio wifi)");
    return;
  }
  LOG_WIFI("applying credentials; restarting WiFi");
  stopWifi();
  startWifi();
  LOG_RADIO("mode=%s status=%s", radioModeToString(mode_), status_);
}

// ---------------------------------------------------------------------------
// BLE
// ---------------------------------------------------------------------------
void RadioManager::startBle() {
  // Build the GATT server exactly once and keep it for the whole session.
  // We never NimBLEDevice::deinit() (see stopBle), so on a re-select the stack
  // is already initialized and we only need to re-advertise.
  if (!NimBLEDevice::isInitialized()) {
    NimBLEDevice::init(BLE_DEVICE_NAME);
    s_bleServer = NimBLEDevice::createServer();
    s_bleServer->setCallbacks(&s_serverCallbacks);

    NimBLEService *svc = s_bleServer->createService(BLE_NUS_SERVICE_UUID);
    NimBLECharacteristic *rx = svc->createCharacteristic(
        BLE_NUS_RX_UUID, NIMBLE_PROPERTY::WRITE | NIMBLE_PROPERTY::WRITE_NR);
    rx->setCallbacks(&s_rxCallbacks);
    s_bleTx = svc->createCharacteristic(BLE_NUS_TX_UUID, NIMBLE_PROPERTY::NOTIFY);
    svc->start();

    NimBLEAdvertising *adv = NimBLEDevice::getAdvertising();
    adv->addServiceUUID(BLE_NUS_SERVICE_UUID);
    adv->setName(BLE_DEVICE_NAME);
  }
  s_bleTearingDown = false;
  NimBLEDevice::startAdvertising();

  snprintf(status_, sizeof(status_), "ble:adv");
  LOG_BLE("advertising as '%s' (NUS control)", BLE_DEVICE_NAME);
}

void RadioManager::stopBle() {
  // IMPORTANT: we do NOT call NimBLEDevice::deinit() here. On arduino-esp32
  // 3.2.1 / IDF 5.4, esp_bt_controller_deinit (reached via nimble_port_deinit)
  // crashes and reboots the S3 even after stopAdvertising with no clients
  // connected (NimBLE-Arduino #1008 - an upstream controller-deinit bug). So we
  // just quiesce the stack: stop advertising and drop any client, leaving the
  // controller initialized but idle. Re-selecting BLE re-advertises instantly.
  // Trade-off: once BLE has been used, its controller stays powered until
  // reboot (coexists fine with WiFi); the *control transport* is still
  // exclusive because advertising is off and clients are dropped.
  if (NimBLEDevice::isInitialized()) {
    s_bleTearingDown = true;  // stop onDisconnect from re-advertising
    NimBLEDevice::stopAdvertising();
    if (s_bleServer && s_bleServer->getConnectedCount() > 0) {
      for (uint16_t handle : s_bleServer->getPeerDevices()) {
        s_bleServer->disconnect(handle);
      }
      uint32_t start = millis();
      while (s_bleConnected && (millis() - start) < 1000) delay(10);
    }
  }
  s_bleConnected = false;
  s_bleLineBuf.clear();
  LOG_BLE("stopped (advertising off; stack idle)");
}

// ---------------------------------------------------------------------------
void RadioManager::loop() {
  if (mode_ != RadioMode::Wifi) return;

  // Soft-AP HTTP portal / REST (also handles reconnect requests from POST).
  g_wifiConfig.loop();
  if (g_wifiConfig.takeReconnectRequest()) {
    // Defer slightly so the HTTP response can finish flushing.
    delay(200);
    applyWifiCredentials();
    return;
  }

  if (softAp_ || WiFi.status() != WL_CONNECTED) return;

  if (!s_tcpClient || !s_tcpClient.connected()) {
    WiFiClient nc = s_tcpServer.available();
    if (nc) {
      s_tcpClient = nc;
      s_tcpLineBuf.clear();
      s_tcpAuthed = !controlAuthRequired();
      LOG_WIFI("control client connected");
    }
  }
  if (s_tcpClient && s_tcpClient.connected()) {
    while (s_tcpClient.available()) {
      char ch = (char)s_tcpClient.read();
      if (ch == '\r') continue;
      if (ch == '\n') {
        if (!s_tcpLineBuf.empty()) {
          dispatchControlLine(s_tcpLineBuf, "wifi", &s_tcpAuthed);
        }
        s_tcpLineBuf.clear();
      } else if (s_tcpLineBuf.size() < 256) {
        s_tcpLineBuf.push_back(ch);
      }
    }
  } else {
    s_tcpAuthed = false;
  }
}

const char *RadioManager::statusStr() {
  if (mode_ == RadioMode::Ble) {
    snprintf(status_, sizeof(status_), "ble:%s", s_bleConnected ? "conn" : "adv");
  } else if (mode_ == RadioMode::Wifi) {
    if (softAp_) {
      snprintf(status_, sizeof(status_), "wifi:ap");
    } else if (WiFi.status() == WL_CONNECTED) {
      snprintf(status_, sizeof(status_), "wifi:%s", WiFi.localIP().toString().c_str());
    }
  }
  return status_;
}

void RadioManager::sendToControl(const char *line) {
  if (mode_ == RadioMode::Ble && s_bleTx && s_bleConnected) {
    s_bleTx->setValue((const uint8_t *)line, strlen(line));
    s_bleTx->notify();
  } else if (mode_ == RadioMode::Wifi && s_tcpClient && s_tcpClient.connected()) {
    s_tcpClient.print(line);
    s_tcpClient.print("\n");
  }
}
