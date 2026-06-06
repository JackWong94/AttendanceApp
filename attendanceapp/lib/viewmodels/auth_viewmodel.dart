import 'package:flutter/material.dart';

class AuthViewModel extends ChangeNotifier {
  String? _userId;
  String? _tenantId;
  bool _isLoggedIn = false;

  String? get userId => _userId;
  String? get tenantId => _tenantId;
  bool get isLoggedIn => _isLoggedIn;

  // ✅ Call this after login success
  void login({
    required String userId,
    required String tenantId,
  }) {
    _userId = userId;
    _tenantId = tenantId;
    _isLoggedIn = true;

    notifyListeners();
  }

  void logout() {
    _userId = null;
    _tenantId = null;
    _isLoggedIn = false;

    notifyListeners();
  }
}