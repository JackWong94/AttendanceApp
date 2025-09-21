import 'package:flutter/material.dart';
import 'package:attendanceapp/pages/login_user_page.dart';
import 'package:attendanceapp/services/authentication_service.dart';
import 'package:attendanceapp/services/user_model_service.dart';
import 'package:attendanceapp/services/camera_service.dart';
import 'package:attendanceapp/services/face_model_service.dart';
import 'package:attendanceapp/services/tenant_model_service.dart';
import '../models/tenant_model.dart';

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
      await TenantModelService.instance.setTenant(TenantModel.devTenant);
      await TenantModelService.instance.setTenant(TenantModel.proTenant);
      // 2️⃣ Fetch tenantId from TenantModelService
      final tenantId = await TenantModelService.instance.getTenantIdByEmail(email);
      if (tenantId == null) {
        throw Exception("No tenant found for this user");
      }

      // 3️⃣ Initialize UserModelService with tenantId
      UserModelService.init(tenantId: tenantId);

      // 4️⃣ Initialize camera & face recognition
      await CameraService().initCamera(forceReinitOnWeb: true);
      await FaceModelService.initialize();
      await FaceModelService.warmUp();

      // 5️⃣ Navigate to main page
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => LoginUserPage()),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Login failed: $e")));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: screenWidth * 0.05, // 5% padding from left and right
              vertical: 32,
            ),
            child: Container(
              padding: const EdgeInsets.all(32),
              constraints: const BoxConstraints(maxWidth: 400),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: const [BoxShadow(blurRadius: 10, color: Colors.black12)],
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      "Admin Login",
                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 24),
                    TextFormField(
                      controller: _emailController,
                      decoration: const InputDecoration(
                          labelText: "Email", border: OutlineInputBorder()),
                      validator: (val) =>
                      val == null || !val.contains("@") ? "Enter a valid email" : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _passwordController,
                      obscureText: true,
                      decoration: const InputDecoration(
                          labelText: "Password", border: OutlineInputBorder()),
                      validator: (val) =>
                      val == null || val.length < 6 ? "Password too short" : null,
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
}
