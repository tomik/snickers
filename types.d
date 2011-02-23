
import std.exception;

class SystemExit : Exception {
  this() {
    super("app exit");
  }
}

/**
 * Global configuration class.
 * This is a singleton (though not enforced).
 */
struct Config {
  bool mBenchmark = false;
  bool mPlayout = false;
}

static Config config;

