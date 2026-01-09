/// Test-only configuration options.
///
/// These options are designed to stabilize widget tests by disabling any
/// auto-start background work (timers/streams/SWR refreshes) that could
/// continuously schedule frames and cause `pumpAndSettle()` to hang.
///
/// In production, these values should remain at their defaults.
class TestConfig {
  /// When true, app bootstrap should avoid starting background work
  /// automatically in providers/controllers.
  ///
  /// Default is false so app behavior is unchanged outside of tests.
  static bool disableAutoStart = false;

  // PUBLIC_INTERFACE
  static void reset() {
    /// Resets all test configuration overrides back to defaults.
    disableAutoStart = false;
  }
}
