#include "WifiCredentials.h"

#include <Preferences.h>

#include "Config.h"
#include "Logging.h"

namespace {

Preferences s_prefs;
bool s_ready = false;

constexpr const char *kNs = "wifi";
constexpr const char *kKeyProv = "provisioned";
constexpr const char *kKeySsid = "ssid";
constexpr const char *kKeyPass = "pass";

bool openRw() {
  if (!s_ready) return false;
  return s_prefs.begin(kNs, false);
}

bool openRo() {
  if (!s_ready) return false;
  return s_prefs.begin(kNs, true);
}

}  // namespace

void WifiCredentials::begin() {
  s_ready = true;
  if (!openRw()) {
    LOG_WIFI("nvs open failed");
    s_ready = false;
    return;
  }
  const bool provisioned = s_prefs.getBool(kKeyProv, false);
  if (!provisioned) {
    const String compileSsid = WIFI_SSID;
    if (compileSsid.length() > 0) {
      s_prefs.putString(kKeySsid, compileSsid);
      s_prefs.putString(kKeyPass, WIFI_PASS);
      s_prefs.putBool(kKeyProv, true);
      LOG_WIFI("nvs seeded from compile-time SSID=\"%s\"", compileSsid.c_str());
    } else {
      LOG_WIFI("nvs empty (no compile-time SSID); Soft-AP available");
    }
  }
  s_prefs.end();
}

bool WifiCredentials::isProvisioned() {
  if (!openRo()) return false;
  const bool v = s_prefs.getBool(kKeyProv, false);
  s_prefs.end();
  return v;
}

WifiCreds WifiCredentials::get() {
  WifiCreds c;
  if (!openRo()) return c;
  c.ssid = s_prefs.getString(kKeySsid, "");
  c.pass = s_prefs.getString(kKeyPass, "");
  s_prefs.end();
  return c;
}

bool WifiCredentials::hasSsid() {
  return get().ssid.length() > 0;
}

bool WifiCredentials::save(const String &ssid, const String &pass) {
  if (ssid.length() == 0) return false;
  if (ssid.length() > 32) return false;
  if (pass.length() > 63) return false;
  if (!openRw()) return false;
  s_prefs.putString(kKeySsid, ssid);
  s_prefs.putString(kKeyPass, pass);
  s_prefs.putBool(kKeyProv, true);
  s_prefs.end();
  LOG_WIFI("nvs saved SSID=\"%s\" (pass_len=%u)", ssid.c_str(),
           (unsigned)pass.length());
  return true;
}

bool WifiCredentials::clear() {
  if (!openRw()) return false;
  s_prefs.putString(kKeySsid, "");
  s_prefs.putString(kKeyPass, "");
  s_prefs.putBool(kKeyProv, true);  // provisioned-empty => Soft-AP, ignore compile secrets
  s_prefs.end();
  LOG_WIFI("nvs cleared (Soft-AP on next radio wifi)");
  return true;
}
