import 'dart:async';
import 'package:flutter/material.dart';
import 'package:attendanceapp/widgets/camera_placeholder.dart';
import 'package:attendanceapp/pages/web_login_page.dart';
import 'package:attendanceapp/pages/register_user_page.dart';
import 'package:attendanceapp/pages/attendance_page.dart';
import 'package:attendanceapp/services/camera_service.dart';
import 'package:attendanceapp/services/face_recognition_service.dart';
import 'package:attendanceapp/services/attendance_service.dart';
import 'package:attendanceapp/services/authentication_service.dart';
import 'package:attendanceapp/models/user_model.dart';
import '../main.dart'; // routeObserver
import 'package:camera/camera.dart';
import 'package:attendanceapp/services/tenant_model_service.dart';

class LoginUserPage extends StatefulWidget {
  const LoginUserPage({super.key});

  @override
  State<LoginUserPage> createState() => _LoginUserPageState();
}

class _LoginUserPageState extends State<LoginUserPage> with RouteAware {
  final CameraService _cameraService = CameraService();
  final AttendanceService _attendanceService = AttendanceService();

  bool _cameraTimedOut = false;
  Timer? _cameraTimer;

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Subscribe to route changes
    routeObserver.subscribe(this, ModalRoute.of(context)!);
  }

  @override
  void dispose() {
    _cameraTimer?.cancel();
    routeObserver.unsubscribe(this);
    super.dispose();
  }

  /// Refresh camera when returning to this page
  @override
  void didPopNext() {
    _initCamera();
    setState(() {});
  }

  /// Initialize camera with 1-minute fallback timer
  void _initCamera() {
    _cameraTimedOut = false;

    _cameraService.initCamera(forceReinitOnWeb: true).then((_) {
      if (mounted) setState(() {});
    });

    // Cancel previous timer if any
    _cameraTimer?.cancel();
    _cameraTimer = Timer(const Duration(minutes: 1), () {
      if (mounted && !_cameraService.isInitialized) {
        setState(() {
          _cameraTimedOut = true;
        });
      }
    });
  }

  Future<void> _handleScan({required bool isScanIn}) async {
    try {
      if (!_cameraService.isInitialized) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Camera not ready")),
        );
        return;
      }

      final picture = await _cameraService.controller!.takePicture();
      final bytes = await picture.readAsBytes();

      final UserModel? user = await FaceRecognitionService.recognizeUser(bytes);
      if (user == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("❌ Face not recognized")),
        );
        return;
      }

      await _attendanceService.scanUser(user: user, isScanIn: isScanIn);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "✅ ${user.name} ${isScanIn ? 'scanned in' : 'scanned out'} successfully",
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error during scan: $e")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(TenantModelService.instance.currentTenantName)),
      endDrawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            const DrawerHeader(
              decoration: BoxDecoration(color: Colors.blue),
              child: Text(
                "Settings",
                style: TextStyle(color: Colors.white, fontSize: 20),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.person_add),
              title: const Text("Register New User"),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const RegisterUserPage()),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.assignment),
              title: const Text("Attendance"),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AttendancePage()),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text("Log out"),
              onTap: () async {
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
              },
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                const Text(
                  "Welcome! Please scan to login/logout",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 30),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ElevatedButton.icon(
                      onPressed: () => _handleScan(isScanIn: true),
                      icon: const Icon(Icons.login),
                      label: const Text("Scan In"),
                    ),
                    const SizedBox(width: 88),
                    ElevatedButton.icon(
                      onPressed: () => _handleScan(isScanIn: false),
                      icon: const Icon(Icons.logout),
                      label: const Text("Scan Out"),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: Center(
              child: FutureBuilder<void>(
                future: _cameraService.initializeFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    // Still initializing → show loading
                    return const Center(child: CircularProgressIndicator());
                  } else if (snapshot.hasError) {
                    // Initialization failed → show placeholder
                    return const CameraPlaceholder(
                      message: "Camera error or not supported on this platform",
                    );
                  } else if (_cameraService.controller != null &&
                      _cameraService.controller!.value.isInitialized) {
                    // Camera ready → show preview
                    return Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: AspectRatio(
                        aspectRatio: _cameraService.controller!.value.aspectRatio,
                        child: CameraPreview(_cameraService.controller!),
                      ),
                    );
                  } else {
                    // Camera still null or unavailable → show loading
                    return const Center(child: CircularProgressIndicator());
                  }
                },
              ),
            ),
          ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }
}
