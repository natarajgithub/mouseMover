#include "WifiConfigServer.h"

#include <cctype>
#include <WebServer.h>
#include <WiFi.h>

#include "CommandSink.h"
#include "Config.h"
#include "ControlAuth.h"
#include "Logging.h"
#include "WifiCredentials.h"

WifiConfigServer g_wifiConfig;

namespace {

WebServer *s_server = nullptr;

String jsonEscape(const String &in) {
  String out;
  out.reserve(in.length() + 8);
  for (size_t i = 0; i < in.length(); i++) {
    char c = in[i];
    if (c == '"' || c == '\\') {
      out += '\\';
      out += c;
    } else if (c == '\n') {
      out += "\\n";
    } else if (c == '\r') {
      out += "\\r";
    } else {
      out += c;
    }
  }
  return out;
}

bool jsonGetString(const String &body, const char *key, String &out) {
  String needle = String("\"") + key + "\"";
  int k = body.indexOf(needle);
  if (k < 0) return false;
  int colon = body.indexOf(':', k + needle.length());
  if (colon < 0) return false;
  int q1 = body.indexOf('"', colon + 1);
  if (q1 < 0) return false;
  String val;
  for (int i = q1 + 1; i < (int)body.length(); i++) {
    char c = body[i];
    if (c == '\\' && i + 1 < (int)body.length()) {
      val += body[i + 1];
      i++;
      continue;
    }
    if (c == '"') {
      out = val;
      return true;
    }
    val += c;
  }
  return false;
}

bool jsonGetInt(const String &body, const char *key, int &out) {
  String needle = String("\"") + key + "\"";
  int k = body.indexOf(needle);
  if (k < 0) return false;
  int colon = body.indexOf(':', k + needle.length());
  if (colon < 0) return false;
  int i = colon + 1;
  while (i < (int)body.length() && isspace((unsigned char)body[i])) i++;
  if (i >= (int)body.length()) return false;
  bool neg = false;
  if (body[i] == '-') {
    neg = true;
    i++;
  } else if (body[i] == '+') {
    i++;
  }
  if (i >= (int)body.length() || !isdigit((unsigned char)body[i])) return false;
  long v = 0;
  while (i < (int)body.length() && isdigit((unsigned char)body[i])) {
    v = v * 10 + (body[i] - '0');
    i++;
  }
  out = (int)(neg ? -v : v);
  return true;
}

bool jsonGetBool(const String &body, const char *key, bool &out) {
  String needle = String("\"") + key + "\"";
  int k = body.indexOf(needle);
  if (k < 0) return false;
  int colon = body.indexOf(':', k + needle.length());
  if (colon < 0) return false;
  String rest = body.substring(colon + 1);
  rest.trim();
  if (rest.startsWith("true")) {
    out = true;
    return true;
  }
  if (rest.startsWith("false")) {
    out = false;
    return true;
  }
  // Also accept 1/0
  if (rest.length() && (rest[0] == '1' || rest[0] == '0')) {
    out = rest[0] == '1';
    return true;
  }
  return false;
}

String bodyOrEmpty() {
  if (!s_server || !s_server->hasArg("plain")) return String();
  return s_server->arg("plain");
}

}  // namespace

void WifiConfigServer::handleCors() {
  if (!s_server) return;
  s_server->sendHeader("Access-Control-Allow-Origin", "*");
  s_server->sendHeader("Access-Control-Allow-Methods", "GET, POST, OPTIONS");
  s_server->sendHeader("Access-Control-Allow-Headers",
                       "Content-Type, X-API-Token, Authorization");
}

bool WifiConfigServer::isSoftApProvisioning() const {
  const bool ap = WiFi.getMode() & WIFI_AP;
  const bool staUp = (WiFi.getMode() & WIFI_STA) && (WiFi.status() == WL_CONNECTED);
  return ap && !staUp;
}

bool WifiConfigServer::requireApiAuth() {
  if (!controlAuthRequired()) return true;
  if (!s_server) return false;

  String token;
  if (s_server->hasHeader("X-API-Token")) {
    token = s_server->header("X-API-Token");
  } else if (s_server->hasHeader("Authorization")) {
    String auth = s_server->header("Authorization");
    if (auth.startsWith("Bearer ") || auth.startsWith("bearer ")) {
      token = auth.substring(7);
      token.trim();
    }
  }
  if (controlTokenMatches(token.c_str())) return true;
  sendErr(401, "unauthorized");
  return false;
}

void WifiConfigServer::handleOptions() {
  handleCors();
  s_server->send(204);
}

void WifiConfigServer::sendOk(const String &extraJson) {
  handleCors();
  String json = "{\"ok\":true";
  if (extraJson.length()) {
    json += ",";
    json += extraJson;
  }
  json += "}";
  s_server->send(200, "application/json", json);
}

void WifiConfigServer::sendErr(int code, const char *error) {
  handleCors();
  s_server->send(code, "application/json",
                 String("{\"ok\":false,\"error\":\"") + error + "\"}");
}

void WifiConfigServer::handleRoot() {
  handleCors();
  const bool ap = WiFi.getMode() & WIFI_AP;
  if (ap && !(WiFi.getMode() & WIFI_STA && WiFi.status() == WL_CONNECTED)) {
    static const char kPage[] PROGMEM = R"HTML(
<!DOCTYPE html><html><head><meta name="viewport" content="width=device-width,initial-scale=1">
<title>usb-hid-s3 WiFi setup</title>
<style>
body{font-family:system-ui,sans-serif;max-width:28rem;margin:2rem auto;padding:0 1rem}
label{display:block;margin-top:1rem}input{width:100%;padding:.5rem;box-sizing:border-box}
button{margin-top:1.25rem;padding:.6rem 1rem;width:100%}
#msg{margin-top:1rem;white-space:pre-wrap}
</style></head><body>
<h1>usb-hid-s3</h1><p>Configure WiFi (2.4 GHz).</p>
<label>SSID <input id="ssid" autocomplete="off"></label>
<label>Password <input id="pass" type="password"></label>
<button id="save">Save &amp; connect</button>
<pre id="msg"></pre>
<script>
async function save(){
  const msg=document.getElementById('msg');
  msg.textContent='Saving...';
  try{
    const r=await fetch('/api/wifi',{method:'POST',headers:{'Content-Type':'application/json'},
      body:JSON.stringify({ssid:document.getElementById('ssid').value,
                           password:document.getElementById('pass').value})});
    msg.textContent=(await r.text());
  }catch(e){msg.textContent=String(e)}
}
document.getElementById('save').onclick=save;
</script></body></html>
)HTML";
    s_server->send_P(200, "text/html", kPage);
    return;
  }
  // STA: compact API index
  String json = "{";
  json += "\"name\":\"" + String(FW_NAME) + "\",";
  json += "\"version\":\"" + String(FW_VERSION) + "\",";
  json += "\"endpoints\":[";
  json += "\"GET /api/status\",\"GET /api/jiggle\",\"POST /api/jiggle\",";
  json += "\"POST /api/move\",\"POST /api/type\",\"POST /api/key\",\"POST /api/click\",";
  json += "\"GET /api/wifi\",\"POST /api/wifi\"";
  json += "]}";
  s_server->send(200, "application/json", json);
}

void WifiConfigServer::handleGetWifi() {
  if (!isSoftApProvisioning() && !requireApiAuth()) return;
  handleCors();
  WifiCreds c = WifiCredentials::get();
  const bool ap = WiFi.getMode() & WIFI_AP;
  const bool sta = WiFi.getMode() & WIFI_STA;
  String json = "{";
  json += "\"mode\":\"";
  if (ap && sta) json += "ap+sta";
  else if (ap) json += "ap";
  else if (sta) json += "sta";
  else json += "off";
  json += "\",";
  json += "\"configured\":";
  json += WifiCredentials::hasSsid() ? "true" : "false";
  json += ",";
  json += "\"ssid\":\"" + jsonEscape(c.ssid) + "\",";
  json += "\"ap_ssid\":\"" + jsonEscape(String(WIFI_AP_SSID)) + "\",";
  json += "\"ap_ip\":\"" + WiFi.softAPIP().toString() + "\",";
  json += "\"sta_ip\":\"";
  json += (WiFi.status() == WL_CONNECTED) ? WiFi.localIP().toString() : "";
  json += "\",";
  json += "\"http_port\":";
  json += String(WIFI_HTTP_PORT);
  json += ",";
  json += "\"control_port\":";
  json += String(WIFI_CONTROL_PORT);
  json += ",";
  json += "\"auth_required\":";
  json += controlAuthRequired() ? "true" : "false";
  json += "}";
  s_server->send(200, "application/json", json);
}

void WifiConfigServer::handlePostWifi() {
  // Soft-AP setup stays open so a phone can provision WiFi without a token.
  if (!isSoftApProvisioning() && !requireApiAuth()) return;
  const String body = bodyOrEmpty();
  if (!body.length()) {
    sendErr(400, "body required");
    return;
  }
  String ssid, pass;
  if (!jsonGetString(body, "ssid", ssid) || ssid.length() == 0) {
    sendErr(400, "ssid required");
    return;
  }
  if (!jsonGetString(body, "password", pass)) {
    jsonGetString(body, "pass", pass);
  }
  if (!WifiCredentials::save(ssid, pass)) {
    sendErr(500, "nvs save failed");
    return;
  }
  reconnectPending_ = true;
  LOG_WIFI("REST: credentials saved; reconnect pending");
  sendOk("\"reconnecting\":true,\"ssid\":\"" + jsonEscape(ssid) + "\"");
}

void WifiConfigServer::handleClearWifi() {
  if (!requireApiAuth()) return;
  WifiCredentials::clear();
  reconnectPending_ = true;
  sendOk("\"cleared\":true,\"reconnecting\":true");
}

void WifiConfigServer::handleGetStatus() {
  if (!requireApiAuth()) return;
  handleCors();
  String json = "{";
  json += "\"ok\":true,";
  json += "\"name\":\"" + String(FW_NAME) + "\",";
  json += "\"version\":\"" + String(FW_VERSION) + "\",";
  json += "\"uptime_s\":";
  json += String(millis() / 1000);
  json += ",";
  json += "\"heap\":";
  json += String(ESP.getFreeHeap());
  json += ",";
  json += "\"usb\":\"";
  json += deviceHidReady() ? "ready" : "not-ready";
  json += "\",";
  json += "\"jiggle\":";
  json += deviceJiggleEnabled() ? "true" : "false";
  json += ",";
  json += "\"jiggle_interval_ms\":";
  json += String(deviceJiggleIntervalMs());
  json += ",";
  json += "\"sta_ip\":\"";
  json += (WiFi.status() == WL_CONNECTED) ? WiFi.localIP().toString() : "";
  json += "\",";
  json += "\"mdns\":\"";
  json += String(MDNS_HOSTNAME) + ".local";
  json += "\",";
  json += "\"auth_required\":";
  json += controlAuthRequired() ? "true" : "false";
  json += "}";
  s_server->send(200, "application/json", json);
}

void WifiConfigServer::handleGetJiggle() {
  if (!requireApiAuth()) return;
  handleCors();
  String json = "{";
  json += "\"ok\":true,";
  json += "\"enabled\":";
  json += deviceJiggleEnabled() ? "true" : "false";
  json += ",";
  json += "\"interval_ms\":";
  json += String(deviceJiggleIntervalMs());
  json += "}";
  s_server->send(200, "application/json", json);
}

void WifiConfigServer::handlePostJiggle() {
  if (!requireApiAuth()) return;
  const String body = bodyOrEmpty();
  bool enabled = false;
  bool have = jsonGetBool(body, "enabled", enabled);
  if (!have) {
    String onOff;
    if (jsonGetString(body, "state", onOff) || jsonGetString(body, "jiggle", onOff)) {
      onOff.toLowerCase();
      if (onOff == "on" || onOff == "true" || onOff == "1") {
        enabled = true;
        have = true;
      } else if (onOff == "off" || onOff == "false" || onOff == "0") {
        enabled = false;
        have = true;
      }
    }
  }
  if (!have) {
    sendErr(400, "enabled bool required");
    return;
  }
  handleCommandLine(enabled ? "jiggle on" : "jiggle off", "http");
  sendOk(String("\"enabled\":") + (enabled ? "true" : "false"));
}

void WifiConfigServer::handlePostMove() {
  if (!requireApiAuth()) return;
  const String body = bodyOrEmpty();
  int dx = 0, dy = 0, wheel = 0;
  if (!jsonGetInt(body, "dx", dx) || !jsonGetInt(body, "dy", dy)) {
    sendErr(400, "dx and dy required");
    return;
  }
  jsonGetInt(body, "wheel", wheel);
  String cmd = "move " + String(dx) + " " + String(dy);
  if (wheel != 0) cmd += " " + String(wheel);
  handleCommandLine(cmd.c_str(), "http");
  sendOk("\"dx\":" + String(dx) + ",\"dy\":" + String(dy) + ",\"wheel\":" + String(wheel));
}

void WifiConfigServer::handlePostType() {
  if (!requireApiAuth()) return;
  const String body = bodyOrEmpty();
  String text;
  if (!jsonGetString(body, "text", text) || text.length() == 0) {
    sendErr(400, "text required");
    return;
  }
  // Command line: "type <text>" — text may contain spaces.
  String cmd = "type " + text;
  handleCommandLine(cmd.c_str(), "http");
  sendOk("\"len\":" + String(text.length()));
}

void WifiConfigServer::handlePostKey() {
  if (!requireApiAuth()) return;
  const String body = bodyOrEmpty();
  String key;
  if (!jsonGetString(body, "key", key)) jsonGetString(body, "name", key);
  if (!key.length()) {
    sendErr(400, "key required");
    return;
  }
  handleCommandLine(("key " + key).c_str(), "http");
  sendOk("\"key\":\"" + jsonEscape(key) + "\"");
}

void WifiConfigServer::handlePostClick() {
  if (!requireApiAuth()) return;
  const String body = bodyOrEmpty();
  String button = "left";
  jsonGetString(body, "button", button);
  if (!button.length()) button = "left";
  handleCommandLine(("click " + button).c_str(), "http");
  sendOk("\"button\":\"" + jsonEscape(button) + "\"");
}

void WifiConfigServer::begin() {
  if (running_) return;
  if (!s_server) s_server = new WebServer(WIFI_HTTP_PORT);

  static const char *kCollectHeaders[] = {"X-API-Token", "Authorization"};
  s_server->collectHeaders(kCollectHeaders, 2);

  s_server->on("/", HTTP_GET, [this]() { handleRoot(); });

  s_server->on("/api/wifi", HTTP_GET, [this]() { handleGetWifi(); });
  s_server->on("/api/wifi", HTTP_POST, [this]() { handlePostWifi(); });
  s_server->on("/api/wifi", HTTP_OPTIONS, [this]() { handleOptions(); });
  s_server->on("/api/wifi/clear", HTTP_POST, [this]() { handleClearWifi(); });
  s_server->on("/api/wifi/clear", HTTP_OPTIONS, [this]() { handleOptions(); });

  s_server->on("/api/status", HTTP_GET, [this]() { handleGetStatus(); });
  s_server->on("/api/status", HTTP_OPTIONS, [this]() { handleOptions(); });

  s_server->on("/api/jiggle", HTTP_GET, [this]() { handleGetJiggle(); });
  s_server->on("/api/jiggle", HTTP_POST, [this]() { handlePostJiggle(); });
  s_server->on("/api/jiggle", HTTP_OPTIONS, [this]() { handleOptions(); });

  s_server->on("/api/move", HTTP_POST, [this]() { handlePostMove(); });
  s_server->on("/api/move", HTTP_OPTIONS, [this]() { handleOptions(); });

  s_server->on("/api/type", HTTP_POST, [this]() { handlePostType(); });
  s_server->on("/api/type", HTTP_OPTIONS, [this]() { handleOptions(); });

  s_server->on("/api/key", HTTP_POST, [this]() { handlePostKey(); });
  s_server->on("/api/key", HTTP_OPTIONS, [this]() { handleOptions(); });

  s_server->on("/api/click", HTTP_POST, [this]() { handlePostClick(); });
  s_server->on("/api/click", HTTP_OPTIONS, [this]() { handleOptions(); });

  s_server->onNotFound([this]() {
    handleCors();
    s_server->send(404, "application/json", "{\"ok\":false,\"error\":\"not found\"}");
  });
  s_server->begin();
  running_ = true;
  LOG_WIFI("HTTP REST listening on :%d (wifi + control)", WIFI_HTTP_PORT);
}

void WifiConfigServer::stop() {
  if (!running_) return;
  if (s_server) s_server->stop();
  running_ = false;
  LOG_WIFI("HTTP REST stopped");
}

void WifiConfigServer::loop() {
  if (running_ && s_server) s_server->handleClient();
}

bool WifiConfigServer::takeReconnectRequest() {
  if (!reconnectPending_) return false;
  reconnectPending_ = false;
  return true;
}

void WifiConfigServer::requestReconnect() {
  reconnectPending_ = true;
}
