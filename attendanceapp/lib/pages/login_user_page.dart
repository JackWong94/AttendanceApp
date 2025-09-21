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
import 'package:attendanceapp/services/attendance_service.dart' show ScanType;

extension ScanTypeName on ScanType {
  String get displayName {
    switch (this) {
      case ScanType.normal:
        return "Normal";
      case ScanType.lunch:
        return "Lunch";
      case ScanType.ot:
        return "OT";
    }
  }
}

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
  OverlayEntry? _overlayEntry;

  UserModel? _detectedUser;

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    routeObserver.subscribe(this, ModalRoute.of(context)!);
  }

  @override
  void dispose() {
    _cameraTimer?.cancel();
    routeObserver.unsubscribe(this);
    _removeOverlay();
    super.dispose();
  }

  @override
  void didPopNext() {
    _initCamera();
    setState(() {});
  }

  void _initCamera() {
    _cameraTimedOut = false;
    _cameraService.initCamera(forceReinitOnWeb: true).then((_) {
      if (mounted) setState(() {});
    });

    _cameraTimer?.cancel();
    _cameraTimer = Timer(const Duration(minutes: 1), () {
      if (mounted && !_cameraService.isInitialized) {
        setState(() {
          _cameraTimedOut = true;
        });
      }
    });
  }

  Future<UserModel?> _detectPerson() async {
    try {
      if (!_cameraService.isInitialized) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Camera not ready")),
        );
        return null;
      }

      final picture = await _cameraService.controller!.takePicture();
      final bytes = await picture.readAsBytes();

      final user = await FaceRecognitionService.recognizeUser(bytes);
      if (user == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("❌ Face not recognized")),
        );
        return null;
      }
      return user;
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error during detection: $e")),
      );
      return null;
    }
  }

  void _showScanOptionsOverlay({required bool isScanIn, required UserModel user}) {
    _overlayEntry = OverlayEntry(
      builder: (context) => Positioned.fill(
        child: Material(
          color: Colors.black54,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                "Hello, ${user.name}",
                style: const TextStyle(color: Colors.white, fontSize: 24),
              ),
              const SizedBox(height: 20),
              ...ScanType.values.map((type) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(200, 60),
                      textStyle: const TextStyle(fontSize: 18),
                    ),
                    onPressed: () async {
                      _removeOverlay();
                      await _handleScan(user: user, isScanIn: isScanIn, scanType: type);
                    },
                    child: Text("${isScanIn ? 'Scan In' : 'Scan Out'} ${type.displayName}"),
                  ),
                );
              }).toList(),
              const SizedBox(height: 20),
              TextButton(
                onPressed: _removeOverlay,
                child: const Text("Cancel", style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ),
      ),
    );

    Overlay.of(context).insert(_overlayEntry!);
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  Future<void> _handleScanFlow({required bool isScanIn}) async {
    final user = await _detectPerson();
    if (user == null) return;
    _detectedUser = user;
    _showScanOptionsOverlay(isScanIn: isScanIn, user: user);
  }

  Future<void> _handleScan({
    required UserModel user,
    required bool isScanIn,
    required ScanType scanType,
  }) async {
    try {
      // Call your attendance service
      final result = await _attendanceService.scanUser(
        user: user,
        isScanIn: isScanIn,
        scanType: scanType,
      );

      // Show message based on ScanResult
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.message),
          backgroundColor: result.success ? Colors.green : Colors.red,
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      // Catch unexpected errors
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("❌ Error scanning attendance: $e"),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 2),
        ),
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
                      onPressed: () => _handleScanFlow(isScanIn: true),
                      icon: const Icon(Icons.login),
                      label: const Text("Scan In"),
                    ),
                    const SizedBox(width: 20),
                    ElevatedButton.icon(
                      onPressed: () => _handleScanFlow(isScanIn: false),
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
