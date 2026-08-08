#include <unity.h>

#include "JiggleEngine.h"

void setUp() {}
void tearDown() {}

void test_disabled_never_fires() {
  JiggleEngine j(8, 1000);
  int dx = 0, dy = 0;
  TEST_ASSERT_FALSE(j.update(0, dx, dy));
  TEST_ASSERT_FALSE(j.update(100000, dx, dy));
}

void test_fires_immediately_after_enable() {
  JiggleEngine j(8, 1000);
  j.setEnabled(true);
  int dx = 0, dy = 0;
  // First update after enabling should fire so motion is observable.
  TEST_ASSERT_TRUE(j.update(500, dx, dy));
}

void test_respects_interval() {
  JiggleEngine j(8, 1000);
  j.setEnabled(true);
  int dx = 0, dy = 0;
  TEST_ASSERT_TRUE(j.update(0, dx, dy));       // initial burst
  TEST_ASSERT_FALSE(j.update(500, dx, dy));    // too soon
  TEST_ASSERT_FALSE(j.update(999, dx, dy));    // still too soon
  TEST_ASSERT_TRUE(j.update(1000, dx, dy));    // interval elapsed
  TEST_ASSERT_FALSE(j.update(1500, dx, dy));   // reset again
}

void test_delta_within_bounds_and_nonzero() {
  JiggleEngine j(5, 10);
  j.setEnabled(true);
  int t = 0;
  for (int i = 0; i < 200; i++) {
    int dx = 0, dy = 0;
    if (j.update(t, dx, dy)) {
      TEST_ASSERT_TRUE(dx >= -5 && dx <= 5);
      TEST_ASSERT_TRUE(dy >= -5 && dy <= 5);
      TEST_ASSERT_TRUE(dx != 0 || dy != 0);
    }
    t += 10;
  }
}

void test_deterministic_with_seed() {
  JiggleEngine a(8, 10, 0xABCDEF01u);
  JiggleEngine b(8, 10, 0xABCDEF01u);
  a.setEnabled(true);
  b.setEnabled(true);
  int t = 0;
  for (int i = 0; i < 50; i++) {
    int ax = 0, ay = 0, bx = 0, by = 0;
    bool fa = a.update(t, ax, ay);
    bool fb = b.update(t, bx, by);
    TEST_ASSERT_EQUAL(fa, fb);
    if (fa) {
      TEST_ASSERT_EQUAL(ax, bx);
      TEST_ASSERT_EQUAL(ay, by);
    }
    t += 10;
  }
}

void test_ms_until_next() {
  JiggleEngine j(8, 1000);
  j.setEnabled(true);
  int dx = 0, dy = 0;
  j.update(0, dx, dy);  // fires, anchors lastFire=0
  TEST_ASSERT_EQUAL_UINT32(600, j.msUntilNext(400));
  TEST_ASSERT_EQUAL_UINT32(0, j.msUntilNext(1000));
  TEST_ASSERT_EQUAL_UINT32(0, j.msUntilNext(2000));
}

int main(int, char **) {
  UNITY_BEGIN();
  RUN_TEST(test_disabled_never_fires);
  RUN_TEST(test_fires_immediately_after_enable);
  RUN_TEST(test_respects_interval);
  RUN_TEST(test_delta_within_bounds_and_nonzero);
  RUN_TEST(test_deterministic_with_seed);
  RUN_TEST(test_ms_until_next);
  return UNITY_END();
}
