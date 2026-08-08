#include <unity.h>

#include <cstring>

#include "RadioMode.h"

void setUp() {}
void tearDown() {}

void test_to_string() {
  TEST_ASSERT_EQUAL_STRING("none", radioModeToString(RadioMode::None));
  TEST_ASSERT_EQUAL_STRING("wifi", radioModeToString(RadioMode::Wifi));
  TEST_ASSERT_EQUAL_STRING("ble", radioModeToString(RadioMode::Ble));
}

void test_from_string() {
  RadioMode m = RadioMode::None;
  TEST_ASSERT_TRUE(radioModeFromString("WiFi", m));
  TEST_ASSERT_EQUAL(int(RadioMode::Wifi), int(m));
  TEST_ASSERT_TRUE(radioModeFromString("BLE", m));
  TEST_ASSERT_EQUAL(int(RadioMode::Ble), int(m));
  TEST_ASSERT_TRUE(radioModeFromString("off", m));
  TEST_ASSERT_EQUAL(int(RadioMode::None), int(m));
}

void test_from_string_invalid() {
  RadioMode m = RadioMode::Wifi;
  TEST_ASSERT_FALSE(radioModeFromString("zigbee", m));
  TEST_ASSERT_EQUAL(int(RadioMode::Wifi), int(m));  // unchanged
}

int main(int, char **) {
  UNITY_BEGIN();
  RUN_TEST(test_to_string);
  RUN_TEST(test_from_string);
  RUN_TEST(test_from_string_invalid);
  return UNITY_END();
}
