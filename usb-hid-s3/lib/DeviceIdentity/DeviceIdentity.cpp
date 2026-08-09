#include "DeviceIdentity.h"

#include <stdio.h>
#include <string.h>

static char hexNibble(uint8_t v) {
  v &= 0x0f;
  return (char)(v < 10 ? ('0' + v) : ('a' + (v - 10)));
}

bool deviceIdFromMacBytes(const uint8_t mac[6], char outId[13], char outSuffix[5]) {
  if (!mac || !outId || !outSuffix) return false;
  for (int i = 0; i < 6; i++) {
    outId[i * 2] = hexNibble((uint8_t)(mac[i] >> 4));
    outId[i * 2 + 1] = hexNibble(mac[i]);
  }
  outId[12] = '\0';
  outSuffix[0] = outId[8];
  outSuffix[1] = outId[9];
  outSuffix[2] = outId[10];
  outSuffix[3] = outId[11];
  outSuffix[4] = '\0';
  return true;
}

void formatSoftApSsid(const char *suffix4, char out[24]) {
  if (!out) return;
  char up[5] = {'0', '0', '0', '0', '\0'};
  if (suffix4) {
    for (int i = 0; i < 4 && suffix4[i]; i++) {
      char c = suffix4[i];
      if (c >= 'a' && c <= 'f') c = (char)(c - 'a' + 'A');
      up[i] = c;
    }
  }
  snprintf(out, 24, "usb-hid-s3-%s", up);
}

void formatMdnsHostname(const char *suffix4, char out[24]) {
  if (!out) return;
  char low[5] = {'0', '0', '0', '0', '\0'};
  if (suffix4) {
    for (int i = 0; i < 4 && suffix4[i]; i++) {
      char c = suffix4[i];
      if (c >= 'A' && c <= 'F') c = (char)(c - 'A' + 'a');
      low[i] = c;
    }
  }
  snprintf(out, 24, "hid-helper-%s", low);
}

#ifndef UNIT_TEST
#include <esp_mac.h>
#include "Logging.h"

namespace {

bool s_ready = false;
char s_deviceId[13];
char s_suffix[5];
char s_softAp[24];
char s_mdns[24];
char s_mdnsFqdn[32];

void ensureReady() {
  if (s_ready) return;
  uint8_t mac[6] = {0};
  if (esp_read_mac(mac, ESP_MAC_WIFI_STA) != ESP_OK) {
    // Last resort: zeros → still yields a deterministic (bad) id for logging.
    memset(mac, 0, sizeof(mac));
  }
  deviceIdFromMacBytes(mac, s_deviceId, s_suffix);
  formatSoftApSsid(s_suffix, s_softAp);
  formatMdnsHostname(s_suffix, s_mdns);
  snprintf(s_mdnsFqdn, sizeof(s_mdnsFqdn), "%s.local", s_mdns);
  s_ready = true;
  LOG_INFO("device_id=%s soft-ap=\"%s\" mdns=%s", s_deviceId, s_softAp, s_mdnsFqdn);
}

}  // namespace

void DeviceIdentity::begin() { ensureReady(); }

const char *DeviceIdentity::deviceId() {
  ensureReady();
  return s_deviceId;
}

const char *DeviceIdentity::suffix() {
  ensureReady();
  return s_suffix;
}

const char *DeviceIdentity::softApSsid() {
  ensureReady();
  return s_softAp;
}

const char *DeviceIdentity::mdnsHostname() {
  ensureReady();
  return s_mdns;
}

const char *DeviceIdentity::mdnsFqdn() {
  ensureReady();
  return s_mdnsFqdn;
}
#endif  // !UNIT_TEST
