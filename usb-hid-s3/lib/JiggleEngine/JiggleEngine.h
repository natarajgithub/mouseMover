#ifndef JIGGLE_ENGINE_H
#define JIGGLE_ENGINE_H

// Pure, Arduino-free jiggle logic: timing + bounded random delta.
// Deterministic (seedable LCG) so it can be unit-tested under env:native.

#include <cstdint>

class JiggleEngine {
public:
  JiggleEngine(int maxDelta, uint32_t intervalMs, uint32_t seed = 0x12345678u);

  void setEnabled(bool enabled);
  bool isEnabled() const { return enabled_; }

  int maxDelta() const { return maxDelta_; }
  uint32_t intervalMs() const { return intervalMs_; }
  void setIntervalMs(uint32_t ms) { intervalMs_ = ms; }

  // Anchor the interval timer to `nowMs` (call when enabling / at boot).
  void reset(uint32_t nowMs);

  // Advance the clock. If enabled and the interval elapsed, produces a
  // non-zero (dx,dy) within [-maxDelta,maxDelta] and returns true.
  bool update(uint32_t nowMs, int &dx, int &dy);

  // Time (ms) until the next jiggle fires, or 0 if due/disabled.
  uint32_t msUntilNext(uint32_t nowMs) const;

private:
  int nextDelta();  // uniform in [-maxDelta, maxDelta]
  uint32_t rand32();

  int maxDelta_;
  uint32_t intervalMs_;
  bool enabled_ = false;
  uint32_t lastFireMs_ = 0;
  bool anchored_ = false;
  uint32_t rngState_;
};

#endif // JIGGLE_ENGINE_H
