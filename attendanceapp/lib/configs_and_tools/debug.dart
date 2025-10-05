class Debug {
  // Global debug toggle
  static bool _globalEnable = true;

  // Per-module debug toggle
  bool enable;

  // Module name
  String module;

  Debug({this.module = "", this.enable = true});

  void log(String message) {
    assert(() { //this is to make sure that production code does not run logging
      if (_globalEnable && enable) {
        final prefix = module.isNotEmpty ? "[$module] " : "";
        print("$prefix$message");
      }
      return true; // assert callback must return bool
    }());
  }

  // Map to hold active stopwatches per label
  final Map<String, Stopwatch> _timers = {};

  /// Start a timer with a label
  void timeStart(String label) {
    assert(() {
      if (_globalEnable && enable) {
        _timers[label] = Stopwatch()..start();
      }
      return true;
    }());
  }

  /// Stop a timer and log the elapsed time in milliseconds
  void timeEnd(String label) {
    assert(() {
      if (_globalEnable && enable) {
        final stopwatch = _timers[label];
        if (stopwatch != null) {
          stopwatch.stop();
          final prefix = module.isNotEmpty ? "[$module] " : "";
          final elapsed = stopwatch.elapsedMilliseconds;
          print("$prefix$label completed in ⌚  ${elapsed > 0 ? elapsed : 0} ms");
          _timers.remove(label);
        } else {
          print("[$module] Timer '$label' was not started");
        }
      }
      return true;
    }());
  }


  // Optional: methods to enable/disable globally
  static void setGlobalEnable(bool value) => _globalEnable = value;
}
