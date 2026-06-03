"""
rate_limiter.py — Shared token-bucket limiter for Groq API calls.

Replaces the old fixed time.sleep() throttles. Instead of always waiting a fixed
amount, this only blocks a caller when the account is actually at its rate cap.
A small burst capacity lets the first few calls fire instantly, then callers are
smoothly paced to stay under the per-minute limit.

Thread-safe: frame_detector runs inside run_in_threadpool, so multiple worker
threads may call acquire() concurrently. The lock serialises them.
"""

import threading
import time


class TokenBucket:
    def __init__(self, rate_per_min: float, capacity: float):
        self.refill_rate = rate_per_min / 60.0   # tokens added per second
        self.capacity = capacity
        self.tokens = capacity
        self.last = time.monotonic()
        self.lock = threading.Lock()

    def acquire(self):
        """Block only as long as needed to stay within the rate. Returns waited seconds."""
        with self.lock:
            now = time.monotonic()
            # Refill based on elapsed time
            self.tokens = min(self.capacity, self.tokens + (now - self.last) * self.refill_rate)
            self.last = now

            if self.tokens >= 1:
                self.tokens -= 1
                return 0.0

            # Not enough — wait for exactly one token to refill
            wait = (1 - self.tokens) / self.refill_rate
            time.sleep(wait)
            self.tokens = 0.0
            self.last = time.monotonic()
            return wait


# Groq free tier is ~30 requests/min. Stay safely under it with a small burst.
# capacity=6 allows 4 concurrent frames to start instantly; then smoothly throttled at 25/min.
_groq_bucket = TokenBucket(rate_per_min=25, capacity=6)


def groq_throttle():
    """Call right before any Groq API request. Blocks only if near the rate cap."""
    waited = _groq_bucket.acquire()
    if waited > 0.5:
        print(f"[RateLimit] Throttled {waited:.1f}s to stay under Groq cap")
    return waited
