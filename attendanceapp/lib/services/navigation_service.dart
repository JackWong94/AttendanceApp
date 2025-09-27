// lib/services/navigation_service.dart
import 'package:flutter/material.dart';
import '../pages/register_user_page.dart';
import '../pages/attendance_page.dart';
import '../pages/manage_user_page.dart';
import '../pages/web_login_page.dart';
import 'authentication_service.dart';
import 'tenant_model_service.dart';

class NavigationService {
  static void goToRegisterUser(BuildContext context) {
    Navigator.pop(context); // Close drawer first
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const RegisterUserPage()),
    );
  }

  static void goToAttendance(BuildContext context) {
    Navigator.pop(context);
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AttendancePage()),
    );
  }

  static void goToManageUser(BuildContext context) {
    Navigator.pop(context);
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ManageUserPage()),
    );
  }

  static Future<void> logOut(BuildContext context) async {
    Navigator.pop(context);
    final authService = AuthenticationService();
    try {
      await authService.signOut();
      TenantModelService.instance.clearCurrentTenant();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Logout failed: $e")),
      );
      return;
    }
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const WebLoginPage()),
    );
  }
}
