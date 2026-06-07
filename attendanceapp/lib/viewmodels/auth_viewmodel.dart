import 'package:flutter/material.dart';
import 'package:attendanceapp/configs_and_tools/debug.dart';

Debug debug = Debug(module: "auth_viewmodel", enable: true);

class AuthViewModel extends ChangeNotifier {
  String? _tenantId;
  bool _isLoggedIn = false;

  String? get tenantId => _tenantId;
  bool get isLoggedIn => _isLoggedIn;

  // ✅ Call this after login success
  void login({
    required String tenantId,
  }) {
    _tenantId = tenantId;
    _isLoggedIn = true;
    debug.log("Logged in as tenant $tenantId");
    notifyListeners();

  }

  void logout() {
    _tenantId = null;
    _isLoggedIn = false;

    notifyListeners();
  }
}