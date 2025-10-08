import 'dart:async';
import 'package:flutter/material.dart';
import 'package:attendanceapp/widgets/camera_placeholder.dart';
import 'package:attendanceapp/pages/web_login_page.dart';
import 'package:attendanceapp/pages/register_user_page.dart';
import 'package:attendanceapp/pages/attendance_page.dart';
import 'package:attendanceapp/pages/manage_user_page.dart';
import 'package:attendanceapp/services/camera_service.dart';
import 'package:attendanceapp/services/face_recognition_service.dart';
import 'package:attendanceapp/services/attendance_service.dart';
import 'package:attendanceapp/services/authentication_service.dart';
import 'package:attendanceapp/services/navigation_service.dart';
import 'package:attendanceapp/models/user_model.dart';
import '../main.dart'; // routeObserver
import 'package:camera/camera.dart';
import 'package:attendanceapp/services/tenant_model_service.dart';
import 'package:intl/intl.dart'; // add at the top
import 'package:attendanceapp/services/face_model_service.dart';
import 'package:package_info_plus/package_info_plus.dart';

class LoginUserPage extends StatefulWidget {
  const LoginUserPage({super.key});

  @override
  State<LoginUserPage> createState() => _LoginUserPageState();
}

class _LoginUserPageState extends State<LoginUserPage> with RouteAware {
  // ✅ use singleton instance instead of constructor
  final CameraService _cameraService = CameraService.instance;
  final AttendanceService _attendanceService = AttendanceService();
  bool _scanInProgress = false;
  Timer? _cameraTimer;
  OverlayEntry? _overlayEntry;

  UserModel? _detectedUser;

  @override
  void initState() {
    super.initState();
    _initApp();
  }

  Future<void> _initApp() async {
    await _initCamera();
    await _initFaceModel();
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
    _cameraService.disposeCamera(); // ✅ ensure cleanup
    super.dispose();
  }

  @override
  void didPopNext() {
    _initCamera();
    setState(() {});
  }
  Future<void> _initFaceModel() async {
    print("Initializing face recognition models...");
    await FaceModelService.initialize();
    await FaceModelService.warmUp();
    print("Face recognition models ready");
  }
  Future<void> _initCamera() async {

    // ✅ Always dispose first on web before reinit
    await _cameraService.disposeCamera();

    _cameraService.initCamera(forceReinitOnWeb: true).then((_) {
      if (mounted) setState(() {});
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

  void _showScanOverlay({
    required bool isScanIn,
    required UserModel user,
    required DateTime time,
  }) {
    _removeOverlay();

    final formattedTime = DateFormat.Hm().format(time.toLocal());

    _overlayEntry = OverlayEntry(
      builder: (context) => Positioned.fill(
        child: GestureDetector(
          onTap: _removeOverlay,
          child: Material(
            color: Colors.black54,
            child: Center(
              child: FractionallySizedBox(
                widthFactor: 0.6,
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.black87,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        "Hello, ${user.name}",
                        style: const TextStyle(color: Colors.white, fontSize: 24),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 20),
                      Text(
                        "${isScanIn ? 'Signed In' : 'Signed Out'} at $formattedTime",
                        style: const TextStyle(color: Colors.white, fontSize: 20),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        "Tap anywhere to close",
                        style: TextStyle(color: Colors.white70, fontSize: 16),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ),
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
    if (_scanInProgress) return;
    _scanInProgress = true;

    try {
      // ✅ Check if camera is ready first
      if (!_cameraService.isInitialized) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Camera not ready, reinitializing...")),
        );

        await _initCamera(); // 🔁 Reinitialize the camera

        // Give it a short moment to complete UI rebuild
        await Future.delayed(const Duration(seconds: 1));

        if (!_cameraService.isInitialized) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Failed to initialize camera. Please try again.")),
          );
          return;
        }

        // ✅ Force a rebuild
        if (mounted) setState(() {});
      }

      // ✅ Continue scanning flow
      final user = await _detectPerson();
      if (user == null) return;
      _detectedUser = user;

      await _handleScan(user: user, isScanIn: isScanIn);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error during scan: $e")),
      );
    } finally {
      _scanInProgress = false;
    }
  }

  Future<void> _handleScan({
    required UserModel user,
    required bool isScanIn,
  }) async {
    try {
      final now = DateTime.now();

      final message = isScanIn
          ? await _attendanceService.addScanIn(
        userId: user.id,
        time: now,
        url: "cameraImageUrl",
      )
          : await _attendanceService.addScanOut(
        userId: user.id,
        time: now,
        url: "cameraImageUrl",
      );

      final success = message.contains("recorded successfully");

      if (success) {
        _showScanOverlay(
          isScanIn: isScanIn,
          user: user,
          time: now,
        );
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: success ? Colors.green : Colors.red,
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
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
        child: FutureBuilder<PackageInfo>(
          future: PackageInfo.fromPlatform(),
          builder: (context, snapshot) {
            final versionText = snapshot.hasData
                ? "Version ${snapshot.data!.version}"
                : "Loading version...";

            return Column(
              children: [
                Container(
                  width: double.infinity,
                  color: Colors.blue,
                  padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 16),
                  alignment: Alignment.centerLeft,
                  child: const Text(
                    "Settings",
                    style: TextStyle(color: Colors.white, fontSize: 20),
                  ),
                ),
                Expanded(
                  child: ListView(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.person_add),
                        title: const Text("Register New User"),
                        onTap: () => NavigationService.goToRegisterUser(context),
                      ),
                      ListTile(
                        leading: const Icon(Icons.assignment),
                        title: const Text("Attendance"),
                        onTap: () => NavigationService.goToAttendance(context),
                      ),
                      ListTile(
                        leading: const Icon(Icons.manage_accounts),
                        title: const Text("Manage User"),
                        onTap: () => NavigationService.goToManageUser(context),
                      ),
                      ListTile(
                        leading: const Icon(Icons.logout),
                        title: const Text("Log out"),
                        onTap: () => NavigationService.logOut(context),
                      ),
                    ],
                  ),
                ),

                // ✅ Version text at bottom center
                Padding(
                  padding: const EdgeInsets.only(bottom: 16, top: 8),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Divider(thickness: 1),
                      Text(
                        versionText,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.grey,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
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
                    return const Center(child: CircularProgressIndicator());
                  } else if (snapshot.hasError) {
                    return const CameraPlaceholder(
                      message: "Camera error or not supported on this platform",
                    );
                  } else if (_cameraService.controller != null &&
                      _cameraService.controller!.value.isInitialized) {
                    return Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: AspectRatio(
                        aspectRatio: _cameraService.controller!.value.aspectRatio,
                        child: CameraPreview(_cameraService.controller!),
                      ),
                    );
                  } else {
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
