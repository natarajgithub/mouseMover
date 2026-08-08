#include <unity.h>

#include "CommandParser.h"

void setUp() {}
void tearDown() {}

static ParsedCommand P(const char *s) { return CommandParser::parse(s); }

void test_empty_is_none() {
  TEST_ASSERT_EQUAL(int(CmdType::None), int(P("").type));
  TEST_ASSERT_EQUAL(int(CmdType::None), int(P("   ").type));
}

void test_move_basic() {
  ParsedCommand c = P("move 10 -20");
  TEST_ASSERT_EQUAL(int(CmdType::Move), int(c.type));
  TEST_ASSERT_EQUAL(10, c.dx);
  TEST_ASSERT_EQUAL(-20, c.dy);
  TEST_ASSERT_EQUAL(0, c.wheel);
}

void test_move_with_wheel() {
  ParsedCommand c = P("MOVE 1 2 3");
  TEST_ASSERT_EQUAL(int(CmdType::Move), int(c.type));
  TEST_ASSERT_EQUAL(3, c.wheel);
}

void test_move_invalid() {
  TEST_ASSERT_EQUAL(int(CmdType::Unknown), int(P("move 10").type));
  TEST_ASSERT_EQUAL(int(CmdType::Unknown), int(P("move a b").type));
}

void test_click() {
  TEST_ASSERT_EQUAL(int(CmdType::Click), int(P("click").type));
  TEST_ASSERT_EQUAL(int(MouseBtn::Left), int(P("click").button));
  TEST_ASSERT_EQUAL(int(MouseBtn::Right), int(P("click right").button));
  TEST_ASSERT_EQUAL(int(MouseBtn::Middle), int(P("click middle").button));
  TEST_ASSERT_EQUAL(int(CmdType::Unknown), int(P("click sideways").type));
}

void test_type_verbatim() {
  ParsedCommand c = P("type Hello World  42");
  TEST_ASSERT_EQUAL(int(CmdType::Type), int(c.type));
  TEST_ASSERT_EQUAL_STRING("Hello World  42", c.text.c_str());
}

void test_type_requires_text() {
  TEST_ASSERT_EQUAL(int(CmdType::Unknown), int(P("type").type));
  TEST_ASSERT_EQUAL(int(CmdType::Unknown), int(P("type    ").type));
}

void test_key() {
  ParsedCommand c = P("key Enter");
  TEST_ASSERT_EQUAL(int(CmdType::Key), int(c.type));
  TEST_ASSERT_EQUAL_STRING("enter", c.text.c_str());
  TEST_ASSERT_EQUAL(int(CmdType::Unknown), int(P("key").type));
}

void test_jiggle() {
  TEST_ASSERT_EQUAL(int(CmdType::JiggleOn), int(P("jiggle on").type));
  TEST_ASSERT_EQUAL(int(CmdType::JiggleOff), int(P("jiggle off").type));
  TEST_ASSERT_EQUAL(int(CmdType::JiggleStatus), int(P("jiggle status").type));
  TEST_ASSERT_EQUAL(int(CmdType::JiggleStatus), int(P("jiggle").type));
  TEST_ASSERT_EQUAL(int(CmdType::Unknown), int(P("jiggle maybe").type));
}

void test_radio() {
  TEST_ASSERT_EQUAL(int(RadioSel::Wifi), int(P("radio wifi").radio));
  TEST_ASSERT_EQUAL(int(RadioSel::Ble), int(P("radio ble").radio));
  TEST_ASSERT_EQUAL(int(RadioSel::None), int(P("radio none").radio));
  TEST_ASSERT_EQUAL(int(CmdType::Unknown), int(P("radio zigbee").type));
  TEST_ASSERT_EQUAL(int(CmdType::Unknown), int(P("radio").type));
}

void test_wifi() {
  TEST_ASSERT_EQUAL(int(CmdType::WifiStatus), int(P("wifi").type));
  TEST_ASSERT_EQUAL(int(CmdType::WifiStatus), int(P("wifi status").type));
  TEST_ASSERT_EQUAL(int(CmdType::WifiClear), int(P("wifi clear").type));
  ParsedCommand set = P("wifi set MyNet secret pass");
  TEST_ASSERT_EQUAL(int(CmdType::WifiSet), int(set.type));
  TEST_ASSERT_EQUAL_STRING("MyNet", set.text.c_str());
  TEST_ASSERT_EQUAL_STRING("secret pass", set.text2.c_str());
  ParsedCommand openNet = P("wifi set OpenNet");
  TEST_ASSERT_EQUAL(int(CmdType::WifiSet), int(openNet.type));
  TEST_ASSERT_EQUAL_STRING("OpenNet", openNet.text.c_str());
  TEST_ASSERT_EQUAL_STRING("", openNet.text2.c_str());
  TEST_ASSERT_EQUAL(int(CmdType::Unknown), int(P("wifi set").type));
  TEST_ASSERT_EQUAL(int(CmdType::Unknown), int(P("wifi foo").type));
}

void test_simple_verbs() {
  TEST_ASSERT_EQUAL(int(CmdType::Status), int(P("status").type));
  TEST_ASSERT_EQUAL(int(CmdType::Version), int(P("version").type));
  TEST_ASSERT_EQUAL(int(CmdType::Help), int(P("help").type));
  TEST_ASSERT_EQUAL(int(CmdType::Help), int(P("?").type));
}

void test_unknown() {
  ParsedCommand c = P("frobnicate");
  TEST_ASSERT_EQUAL(int(CmdType::Unknown), int(c.type));
  TEST_ASSERT_TRUE(!c.error.empty());
}

int main(int, char **) {
  UNITY_BEGIN();
  RUN_TEST(test_empty_is_none);
  RUN_TEST(test_move_basic);
  RUN_TEST(test_move_with_wheel);
  RUN_TEST(test_move_invalid);
  RUN_TEST(test_click);
  RUN_TEST(test_type_verbatim);
  RUN_TEST(test_type_requires_text);
  RUN_TEST(test_key);
  RUN_TEST(test_jiggle);
  RUN_TEST(test_radio);
  RUN_TEST(test_wifi);
  RUN_TEST(test_simple_verbs);
  RUN_TEST(test_unknown);
  return UNITY_END();
}
