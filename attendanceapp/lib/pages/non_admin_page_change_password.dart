import 'package:flutter/material.dart';
import 'package:attendanceapp/models/user_model.dart';
import 'package:attendanceapp/services/non_admin_authentication_service.dart';

class NonAdminPageChangePassword extends StatefulWidget {
  final UserModel user;

  const NonAdminPageChangePassword({
    super.key,
    required this.user,
  });

  @override
  State<NonAdminPageChangePassword> createState() =>
      _NonAdminPageChangePasswordState();
}

class _NonAdminPageChangePasswordState
    extends State<NonAdminPageChangePassword> {
  final NonAdminAuthenticationService _authService =
      NonAdminAuthenticationService.instance;

  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
  TextEditingController();

  bool _isSubmitting = false;
  bool _obscureNew = true; // separate toggle for new password
  bool _obscureConfirm = true; // separate toggle for confirm password

  Future<void> _changePassword() async {
    final newPwd = _newPasswordController.text.trim();
    final confirmPwd = _confirmPasswordController.text.trim();

    // ✅ Validate using shared service
    final validationError = _authService.validatePassword(newPwd);
    if (validationError != null) {
      _showMessage(validationError);
      return;
    }

    if (newPwd != confirmPwd) {
      _showMessage("Passwords do not match");
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      // 🔒 Only one loader here using setState + CircularProgressIndicator inside button
      await Future.delayed(const Duration(seconds: 1)); // animate loader

      await _authService.changePassword(
        userId: widget.user.id,
        plainPassword: newPwd,
      );

      _showMessage("✅ Password updated successfully");

      _newPasswordController.clear();
      _confirmPasswordController.clear();
    } catch (e) {
      _showMessage(
          "❌ Failed to update password: ${e.toString().replaceAll('Exception: ', '')}");
    } finally {
      setState(() => _isSubmitting = false);
    }
  }

  void _showMessage(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg)),
    );
  }

  @override
  void dispose() {
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Change Password")),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  "Change Password",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 30),

                // New password
                TextFormField(
                  controller: _newPasswordController,
                  obscureText: _obscureNew,
                  decoration: InputDecoration(
                    labelText: "New Password",
                    border: const OutlineInputBorder(),
                    helperText:
                    "Minimum ${NonAdminAuthenticationService.minPasswordLength} characters",
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureNew ? Icons.visibility_off : Icons.visibility,
                      ),
                      onPressed: () =>
                          setState(() => _obscureNew = !_obscureNew),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Confirm password
                TextFormField(
                  controller: _confirmPasswordController,
                  obscureText: _obscureConfirm,
                  decoration: InputDecoration(
                    labelText: "Confirm Password",
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureConfirm ? Icons.visibility_off : Icons.visibility,
                      ),
                      onPressed: () =>
                          setState(() => _obscureConfirm = !_obscureConfirm),
                    ),
                  ),
                ),
                const SizedBox(height: 30),

                ElevatedButton(
                  onPressed: _isSubmitting ? null : _changePassword,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                  )
                      : const Text("Update Password"),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
