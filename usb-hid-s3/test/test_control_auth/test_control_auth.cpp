#include <unity.h>

// Exercise ControlAuth with a non-empty token (default Config has "").
#define CONTROL_API_TOKEN "test-token"
#include "ControlAuth.h"

void test_auth_required_when_token_set() {
  TEST_ASSERT_TRUE(controlAuthRequired());
}

void test_token_match() {
  TEST_ASSERT_TRUE(controlTokenMatches("test-token"));
  TEST_ASSERT_FALSE(controlTokenMatches("wrong"));
  TEST_ASSERT_FALSE(controlTokenMatches(""));
  TEST_ASSERT_FALSE(controlTokenMatches(nullptr));
}

void test_gate_rejects_until_auth() {
  bool authed = false;
  TEST_ASSERT_EQUAL(ControlLineGate::Reject, controlGateLine("move 1 0", &authed));
  TEST_ASSERT_FALSE(authed);
  TEST_ASSERT_EQUAL(ControlLineGate::Consumed, controlGateLine("auth wrong", &authed));
  TEST_ASSERT_FALSE(authed);
  TEST_ASSERT_EQUAL(ControlLineGate::Consumed, controlGateLine("auth test-token", &authed));
  TEST_ASSERT_TRUE(authed);
  TEST_ASSERT_EQUAL(ControlLineGate::Accept, controlGateLine("move 1 0", &authed));
}

void setUp() {}
void tearDown() {}

int main() {
  UNITY_BEGIN();
  RUN_TEST(test_auth_required_when_token_set);
  RUN_TEST(test_token_match);
  RUN_TEST(test_gate_rejects_until_auth);
  return UNITY_END();
}
