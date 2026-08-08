#ifndef WIFI_CREDENTIALS_H
#define WIFI_CREDENTIALS_H

#include <Arduino.h>

/**
 * NVS-backed WiFi STA credentials.
 *
 * Persistence model (Preferences namespace "wifi"):
 *   - `provisioned` (bool): once true, NVS is authoritative (even if ssid empty).
 *   - `ssid` / `pass` (string): STA credentials.
 *
 * First boot (`provisioned` false): seed from compile-time WIFI_SSID/WIFI_PASS
 * if WIFI_SSID is non-empty, then mark provisioned. That preserves the old
 * wifi_secrets.h workflow.
 *
 * `clear()` sets ssid/pass empty and provisioned=true so Soft-AP setup is used
 * even when compile-time secrets still exist in the binary.
 */

struct WifiCreds {
  String ssid;
  String pass;
};

class WifiCredentials {
public:
  // Load from NVS (seeding from compile-time defaults on first boot).
  static void begin();

  static bool hasSsid();
  static WifiCreds get();

  // Persist and mark provisioned. Empty pass is allowed (open network).
  static bool save(const String &ssid, const String &pass);

  // Forget STA creds (forces Soft-AP on next radio wifi).
  static bool clear();

  static bool isProvisioned();
};

#endif  // WIFI_CREDENTIALS_H
