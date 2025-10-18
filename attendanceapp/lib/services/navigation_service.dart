// lib/services/navigation_service.dart
import 'package:flutter/material.dart';
import '../pages/register_user_page.dart';
import '../pages/attendance_page.dart';
import '../pages/manage_user_page.dart';
import '../pages/web_login_page.dart';
import 'package:attendanceapp/services/authentication_service.dart';
import 'tenant_model_service.dart';
import 'user_model_service.dart';
import 'attendance_model_service.dart';

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
    Navigator.pop(context);
    final authService = AuthenticationService();
    try {
      await authService.signOut();
      TenantModelService.instance.clearCurrentTenant(); //Tenant class still need to be active, it just needs to be cleared
      UserModelService.clear(); //UserModelService is not active anymore
      AttendanceModelService.clear(); //AttendanceModelService is not active anymore
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
