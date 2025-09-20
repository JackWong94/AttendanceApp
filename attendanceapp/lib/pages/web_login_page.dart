import 'package:flutter/material.dart';
import 'package:attendanceapp/pages/login_user_page.dart';
import 'package:attendanceapp/services/authentication_service.dart';
import 'package:attendanceapp/services/user_model_service.dart';
import 'package:attendanceapp/services/camera_service.dart';
import 'package:attendanceapp/services/face_model_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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
  String? _selectedTenant = "default"; // Example tenant selection

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      // 1️⃣ Sign in
      await _authService.signIn(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      // 2️⃣ Determine tenant ID from Firestore
      final email = _emailController.text.trim();
      final query = await FirebaseFirestore.instance
          .collection('clients')
          .where('email', isEqualTo: email)
          .limit(1)
          .get();

      if (query.docs.isEmpty) {
        throw Exception("No tenant found for this user");
      }

      final tenantId = query.docs.first.data()['tenantId'] ?? "defaultTenant";
      UserModelService.init(tenantId: tenantId);

      await CameraService().initCamera(forceReinitOnWeb: true);
      await FaceModelService.initialize();
      await FaceModelService.warmUp();

      // 3️⃣ Navigate to main page
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
    return Scaffold(
      body: Center(
        child: Container(
          padding: const EdgeInsets.all(32),
          width: 400,
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
                const Text("Admin Login",
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                const SizedBox(height: 24),
                TextFormField(
                  controller: _emailController,
                  decoration: const InputDecoration(labelText: "Email", border: OutlineInputBorder()),
                  validator: (val) => val == null || !val.contains("@") ? "Enter a valid email" : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: "Password", border: OutlineInputBorder()),
                  validator: (val) => val == null || val.length < 6 ? "Password too short" : null,
                ),
                const SizedBox(height: 24),
                _isLoading
                    ? const CircularProgressIndicator()
                    : ElevatedButton(
                  onPressed: _login,
                  child: const Text("Login"),
                  style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(50)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
