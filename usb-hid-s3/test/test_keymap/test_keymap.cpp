#include <unity.h>

#include "KeyMap.h"

void setUp() {}
void tearDown() {}

void test_letters_and_digits() {
  TEST_ASSERT_EQUAL_HEX8(0x04, KeyMap::lookup("a").keycode);
  TEST_ASSERT_EQUAL_HEX8(0x1D, KeyMap::lookup("z").keycode);
  TEST_ASSERT_EQUAL_HEX8(0x1E, KeyMap::lookup("1").keycode);
  TEST_ASSERT_EQUAL_HEX8(0x27, KeyMap::lookup("0").keycode);
}

void test_named_keys() {
  TEST_ASSERT_EQUAL_HEX8(0x28, KeyMap::lookup("enter").keycode);
  TEST_ASSERT_EQUAL_HEX8(0x28, KeyMap::lookup("return").keycode);
  TEST_ASSERT_EQUAL_HEX8(0x29, KeyMap::lookup("esc").keycode);
  TEST_ASSERT_EQUAL_HEX8(0x2B, KeyMap::lookup("tab").keycode);
  TEST_ASSERT_EQUAL_HEX8(0x2C, KeyMap::lookup("space").keycode);
}

void test_arrows() {
  TEST_ASSERT_EQUAL_HEX8(0x4F, KeyMap::lookup("right").keycode);
  TEST_ASSERT_EQUAL_HEX8(0x50, KeyMap::lookup("left").keycode);
  TEST_ASSERT_EQUAL_HEX8(0x51, KeyMap::lookup("down").keycode);
  TEST_ASSERT_EQUAL_HEX8(0x52, KeyMap::lookup("up").keycode);
}

void test_function_keys() {
  TEST_ASSERT_EQUAL_HEX8(0x3A, KeyMap::lookup("f1").keycode);
  TEST_ASSERT_EQUAL_HEX8(0x45, KeyMap::lookup("f12").keycode);
  TEST_ASSERT_FALSE(KeyMap::lookup("f13").found);
}

void test_combos() {
  KeyCode k = KeyMap::lookup("cmd+space");
  TEST_ASSERT_TRUE(k.found);
  TEST_ASSERT_EQUAL_HEX8(KM_MOD_LGUI, k.modifier);
  TEST_ASSERT_EQUAL_HEX8(0x2C, k.keycode);

  KeyCode c = KeyMap::lookup("ctrl+shift+t");
  TEST_ASSERT_TRUE(c.found);
  TEST_ASSERT_EQUAL_HEX8(KM_MOD_LCTRL | KM_MOD_LSHIFT, c.modifier);
  TEST_ASSERT_EQUAL_HEX8(0x17, c.keycode);  // 't'
}

void test_modifier_only() {
  KeyCode k = KeyMap::lookup("cmd");
  TEST_ASSERT_TRUE(k.found);
  TEST_ASSERT_EQUAL_HEX8(KM_MOD_LGUI, k.modifier);
  TEST_ASSERT_EQUAL_HEX8(0x00, k.keycode);
}

void test_invalid() {
  TEST_ASSERT_FALSE(KeyMap::lookup("nope").found);
  TEST_ASSERT_FALSE(KeyMap::lookup("bogusmod+a").found);
}

int main(int, char **) {
  UNITY_BEGIN();
  RUN_TEST(test_letters_and_digits);
  RUN_TEST(test_named_keys);
  RUN_TEST(test_arrows);
  RUN_TEST(test_function_keys);
  RUN_TEST(test_combos);
  RUN_TEST(test_modifier_only);
  RUN_TEST(test_invalid);
  return UNITY_END();
}
