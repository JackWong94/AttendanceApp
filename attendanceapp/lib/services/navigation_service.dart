// lib/services/navigation_service.dart
import 'package:flutter/material.dart';
import '../pages/register_user_page.dart';
import '../pages/attendance_page.dart';
import '../pages/manage_user_page.dart';
import '../pages/web_login_page.dart';
import 'package:attendanceapp/pages/non_admin_page.dart';
import 'package:attendanceapp/pages/service_portal_admin_page.dart';
import 'package:attendanceapp/services/authentication_service.dart';
import 'tenant_model_service.dart';
import 'user_model_service.dart';
import 'image_model_service.dart';
import 'attendance_model_service.dart';
import 'face_model_service.dart';
import 'notification_model_service.dart';

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

  static void goToNonAdminPage(BuildContext context) {
    Navigator.pop(context);
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const NonAdminPage()),
    );
  }

  static void goToServicePortalAdmin(BuildContext context) async {
    final passwordController = TextEditingController();
    final authService = AuthenticationService();

    final bool? verified = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Password Verification'),
        content: TextField(
          controller: passwordController,
          obscureText: true,
          decoration: const InputDecoration(
            labelText: 'Enter your password',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              final success = await authService.verifyPassword(passwordController.text);
              Navigator.pop(context, success);
            },
            child: const Text('Verify'),
          ),
        ],
      ),
    );
    if (verified == true) {
      Navigator.pop(context);
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const ServicePortalAdminPage()),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Incorrect password')),
      );
    }
  }

  /// Password verification before opening ManageUserPage
  static void goToManageUser(BuildContext context) async {
    final passwordController = TextEditingController();
    final authService = AuthenticationService();

    final bool? verified = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Password Verification'),
        content: TextField(
          controller: passwordController,
          obscureText: true,
          decoration: const InputDecoration(
            labelText: 'Enter your password',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              final success = await authService.verifyPassword(passwordController.text);
              Navigator.pop(context, success);
            },
            child: const Text('Verify'),
          ),
        ],
      ),
    );
    if (verified == true) {
      // Only close drawer **after verification**
      Navigator.pop(context);
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const ManageUserPage()),
      );
    } else if (verified == false) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Incorrect password')),
      );
    }
  }


  static Future<void> logOut(BuildContext context) async {
    final authService = AuthenticationService();
    try {
      await authService.signOut();
      TenantModelService.instance.clearCurrentTenant();
      UserModelService.clear();
      AttendanceModelService.clear();
      ImageModelService.clear();
      NotificationModelService.clear();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Logout failed: $e")),
      );
      return;
    }

    // ✅ Safely pop the current route if possible
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    }

    // ✅ Navigate to WebLoginPage
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const WebLoginPage()),
    );
  }
}
