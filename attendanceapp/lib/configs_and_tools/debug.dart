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

  // Optional: methods to enable/disable globally
  static void setGlobalEnable(bool value) => _globalEnable = value;
}
