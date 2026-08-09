#include <unity.h>
#include <string.h>

#define UNIT_TEST
#include "DeviceIdentity.h"

void test_device_id_from_mac() {
  const uint8_t mac[6] = {0xaa, 0xbb, 0xcc, 0xdd, 0xee, 0xff};
  char id[13];
  char suffix[5];
  TEST_ASSERT_TRUE(deviceIdFromMacBytes(mac, id, suffix));
  TEST_ASSERT_EQUAL_STRING("aabbccddeeff", id);
  TEST_ASSERT_EQUAL_STRING("eeff", suffix);
}

void test_soft_ap_ssid_upper_suffix() {
  char ssid[24];
  formatSoftApSsid("eeff", ssid);
  TEST_ASSERT_EQUAL_STRING("usb-hid-s3-EEFF", ssid);
}

void test_mdns_hostname_lower_suffix() {
  char host[24];
  formatMdnsHostname("EEFF", host);
  TEST_ASSERT_EQUAL_STRING("hid-helper-eeff", host);
}

void test_null_mac_rejected() {
  char id[13];
  char suffix[5];
  TEST_ASSERT_FALSE(deviceIdFromMacBytes(nullptr, id, suffix));
}

void setUp() {}
void tearDown() {}

int main() {
  UNITY_BEGIN();
  RUN_TEST(test_device_id_from_mac);
  RUN_TEST(test_soft_ap_ssid_upper_suffix);
  RUN_TEST(test_mdns_hostname_lower_suffix);
  RUN_TEST(test_null_mac_rejected);
  return UNITY_END();
}
