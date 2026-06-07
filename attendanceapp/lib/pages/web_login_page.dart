import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:attendanceapp/pages/login_user_page.dart';
import 'package:attendanceapp/pages/non_admin_page.dart';
import 'package:attendanceapp/services/authentication_service.dart';
import 'package:attendanceapp/services/user_model_service.dart';
import 'package:attendanceapp/services/attendance_model_service.dart';
import 'package:attendanceapp/services/tenant_model_service.dart';
import 'package:attendanceapp/services/image_model_service.dart';
import 'package:attendanceapp/viewmodels/auth_viewmodel.dart';
import 'package:provider/provider.dart';

class WebLoginPage extends StatefulWidget {
  const WebLoginPage({super.key});

  @override
  State<WebLoginPage> createState() => _WebLoginPageState();
}

class _WebLoginPageState extends State<WebLoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final AuthenticationService _authService = AuthenticationService();

  bool _isLoading = false;
  bool _checkingSession = true; // show loading screen while checking saved login

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // Wait a tick for Firebase to fully initialize on web
      await Future.delayed(const Duration(milliseconds: 200));
      await _checkRememberedLogin();
    });
  }

  Future<void> _checkRememberedLogin() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      // Already logged in → continue setup flow
      await _continueAfterLogin(user.email!);
    } else {
      // No remembered login → show login form
      setState(() => _checkingSession = false);
    }
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      // 1️⃣ Sign in with email & password
      await _authService.signIn(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      final email = _emailController.text.trim();
      await _continueAfterLogin(email);
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Login failed: $e")));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _continueAfterLogin(String email) async {
    try {
      // 2️⃣ Fetch tenant object
      final tenant = await TenantModelService.instance.getTenantByEmail(email);
      if (tenant == null) throw Exception("No tenant found for this user");
      context.read<AuthViewModel>().login(
        tenantId: tenant.tenantId,
      );
      TenantModelService.instance.setCurrentTenant(tenant);

      // 3️⃣ Initialize user service
      UserModelService.init(tenantId: tenant.tenantId);
      AttendanceModelService.init(tenantId: tenant.tenantId);
      ImageModelService.init(tenantId: tenant.tenantId);

      // 4️⃣ Navigate
      if (mounted) {
        Navigator.pushReplacement(
          context,
          TenantModelService.instance.getCurrentTenantRole == "admin"
              ? MaterialPageRoute(builder: (_) => const LoginUserPage())
              : MaterialPageRoute(builder: (_) => const NonAdminPage()),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Setup failed after login: $e")),
      );
      setState(() => _checkingSession = false); // go back to login form
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    // ✅ 1. Show a full-screen loading spinner if still checking session
    if (_checkingSession) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // ✅ 2. Otherwise show login form
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: screenWidth * 0.05,
              vertical: 32,
            ),
            child: Container(
              padding: const EdgeInsets.all(32),
              constraints: const BoxConstraints(maxWidth: 400),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: const [
                  BoxShadow(blurRadius: 10, color: Colors.black12)
                ],
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      "Attendance App Login",
                      style:
                      TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 24),
                    TextFormField(
                      controller: _emailController,
                      decoration: const InputDecoration(
                        labelText: "Email",
                        border: OutlineInputBorder(),
                      ),
                      validator: (val) => val == null || !val.contains("@")
                          ? "Enter a valid email"
                          : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _passwordController,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: "Password",
                        border: OutlineInputBorder(),
                      ),
                      validator: (val) =>
                      val == null || val.length < 6
                          ? "Password too short"
                          : null,
                    ),
                    const SizedBox(height: 24),
                    _isLoading
                        ? const CircularProgressIndicator()
                        : ElevatedButton(
                      onPressed: _login,
                      child: const Text("Login"),
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size.fromHeight(50),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
  @override
  void dispose() {
    super.dispose();
  }
}
