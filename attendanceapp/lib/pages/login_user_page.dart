import 'dart:async';
import 'package:flutter/material.dart';
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
import 'package:intl/intl.dart';
import 'package:attendanceapp/services/face_model_service.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:attendanceapp/utils/snackbar_helper.dart';
import 'package:attendanceapp/widgets/scan_beam.dart';
import 'package:attendanceapp/widgets/scan_overlay_manager.dart';
import 'package:attendanceapp/widgets/user_confirm_overlay_widget.dart';
import 'package:attendanceapp/widgets/face_recognition_widget.dart';
import 'package:attendanceapp/widgets/emergency_scan_overlay_widget.dart';

class LoginUserPage extends StatefulWidget {
  const LoginUserPage({super.key});

  @override
  State<LoginUserPage> createState() => _LoginUserPageState();
}

class _LoginUserPageState extends State<LoginUserPage>
    with RouteAware, SingleTickerProviderStateMixin {
  static const String appVersion = "Version: 1.0.1";
  final CameraService _cameraService = CameraService.instance;
  final AttendanceService _attendanceService = AttendanceService();
  final ScanOverlayManager _overlayManager = ScanOverlayManager();
  final UserConfirmOverlayWidget _confirmOverlayWidget = UserConfirmOverlayWidget();

  bool _scanInProgress = false;
  Timer? _cameraTimer;

  late AnimationController _scanController;
  late Animation<double> _scanAnimation;

  UserModel? _detectedUser;

  @override
  void initState() {
    super.initState();
    _initApp();

    // ✅ Beam animation controller (always start top → bottom → top)
    _scanController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _scanAnimation = CurvedAnimation(
      parent: _scanController,
      curve: Curves.linear
    );
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
    _overlayManager.remove();
    _cameraTimer?.cancel();
    routeObserver.unsubscribe(this);
    _cameraService.disposeCamera();
    _scanController.dispose();
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
    await _cameraService.disposeCamera();

    _cameraService.initCamera(forceReinitOnWeb: true).then((_) {
      if (mounted) setState(() {});
    });
  }

  Future<UserModel?> _detectPerson() async {
    try {
      if (!_cameraService.isInitialized) {
        SnackBarHelper.show(context, "Camera not ready");
        return null;
      }

      final picture = await _cameraService.controller!.takePicture();
      final bytes = await picture.readAsBytes();

      final user = await FaceRecognitionService.recognizeUser(bytes);
      if (user == null) {
        SnackBarHelper.show(context, "❌ Face not recognized");
        return null;
      }
      return user;
    } catch (e) {
        SnackBarHelper.show(context, e.toString());
        return null;
    }
  }

  Future<void> _handleScanFlow({required bool isScanIn}) async {
    if (_scanInProgress) return;
    setState(() => _scanInProgress = true);

    try {
      final user = await _detectPerson();
      if (user == null) return;

      // ✅ Show confirmation overlay (no rebuilds)
      _confirmOverlayWidget.show(
        context: context,
        user: user,
        onConfirm: () async {
          await _handleScan(user: user, isScanIn: isScanIn);
        },
        onReject: () {
          SnackBarHelper.show(context, "Please retry scanning.");
        },
      );
    } catch (e) {
      SnackBarHelper.show(context, "Error during scan: $e");
    } finally {
      setState(() => _scanInProgress = false);
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
        _overlayManager.show(
          context: context,
          isScanIn: isScanIn,
          user: user,
          time: now,
        );
      }

      SnackBarHelper.show(
        context,
        message,
        backgroundColor: success ? Colors.green : Colors.red,
      );
    } catch (e) {
      SnackBarHelper.show(
        context,
        "❌ Error scanning attendance: $e",
        backgroundColor: Colors.red,
      );
    }
  }

  Future<bool?> _confirmUserDialog(UserModel user) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          title: const Text("Confirm Identity"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.face, size: 60, color: Colors.blue),
              const SizedBox(height: 16),
              Text(
                "Detected: ${user.name}",
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                "Is this you?",
                style: TextStyle(color: Colors.grey[700]),
              ),
            ],
          ),
          actionsAlignment: MainAxisAlignment.spaceEvenly,
          actions: [
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
              ),
              onPressed: () => Navigator.of(context).pop(true),
              icon: const Icon(Icons.check),
              label: const Text("It's Me"),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
              ),
              onPressed: () => Navigator.of(context).pop(false),
              icon: const Icon(Icons.close),
              label: const Text("Not Me"),
            ),
          ],
        );
      },
    );
  }

  Future<void> _handleEmergencyScan() async {
    try {
      if (!_cameraService.isInitialized) {
        SnackBarHelper.show(context, "Camera not ready");
        return;
      }

      // Capture photo from camera
      final picture = await _cameraService.controller!.takePicture();
      final bytes = await picture.readAsBytes();

      // ✅ Show emergency overlay (will not reset/rebuild page)
      EmergencyScanOverlayWidget.show(
        context: context,
        imageBytes: bytes,
        onConfirm: (selectedUser, isScanIn) async {
          final now = DateTime.now();

          final message = isScanIn
              ? await _attendanceService.addScanIn(
            userId: selectedUser.id,
            time: now,
            url: "emergencyPhotoUrl",
          )
              : await _attendanceService.addScanOut(
            userId: selectedUser.id,
            time: now,
            url: "emergencyPhotoUrl",
          );

          final success = message.contains("recorded successfully");

          // ✅ Show the same black overlay animation (like normal ScanIn/Out)
          if (success) {
            _overlayManager.show(
              context: context,
              isScanIn: isScanIn,
              user: selectedUser,
              time: now,
            );
          }

          SnackBarHelper.show(
            context,
            message,
            backgroundColor: success ? Colors.green : Colors.red,
          );
        },
      );
    } catch (e) {
      SnackBarHelper.show(context, "Error during emergency scan: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
        onWillPop: () async {
          if (_overlayManager.isVisible) {
            _overlayManager.remove();
            return false; // prevent exiting when overlay is visible
          }
          return true;
        },
        child: Scaffold(
          appBar:
          AppBar(title: Text(TenantModelService.instance.currentTenantName)),
          endDrawer: Drawer(
            child: FutureBuilder<PackageInfo>(
              future: PackageInfo.fromPlatform(),
              builder: (context, snapshot) {
                final versionText = appVersion;

                return Column(
                  children: [
                    Container(
                      width: double.infinity,
                      color: Colors.blue,
                      padding:
                      const EdgeInsets.symmetric(vertical: 40, horizontal: 16),
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
                            onTap: () =>
                                NavigationService.goToRegisterUser(context),
                          ),
                          ListTile(
                            leading: const Icon(Icons.assignment),
                            title: const Text("Attendance"),
                            onTap: () =>
                                NavigationService.goToAttendance(context),
                          ),
                          ListTile(
                            leading: const Icon(Icons.manage_accounts),
                            title: const Text("Manage User"),
                            onTap: () =>
                                NavigationService.goToManageUser(context),
                          ),
                          ListTile(
                            leading: const Icon(Icons.logout),
                            title: const Text("Log out"),
                            onTap: () => NavigationService.logOut(context),
                          ),
                        ],
                      ),
                    ),
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
                          onPressed: _scanInProgress
                              ? null
                              : () => _handleScanFlow(isScanIn: true),
                          icon: const Icon(Icons.login),
                          label: const Text("Scan In"),
                        ),
                        const SizedBox(width: 20),
                        ElevatedButton.icon(
                          onPressed: _scanInProgress
                              ? null
                              : () => _handleScanFlow(isScanIn: false),
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
                  child: Padding(
                    padding: const EdgeInsets.all(24.0), // ✅ same as your previous layout
                    child: _cameraService.controller != null &&
                        _cameraService.controller!.value.isInitialized
                        ? AspectRatio(
                      aspectRatio: _cameraService.controller!.value.aspectRatio,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12), // optional rounded corners
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            FaceRecognitionWidget (
                              controller: _cameraService.controller!,
                              showScanBeam: _scanInProgress,
                            ),
                          ],
                        ),
                      ),
                    )
                        : const Center(child: CircularProgressIndicator()),
                  ),
                ),
              ),

              const SizedBox(height: 10),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
                onPressed: _scanInProgress ? null : _handleEmergencyScan,
                icon: const Icon(Icons.warning),
                label: const Text("Emergency Scan"),
              ),
              const SizedBox(height: 30),
            ],
          ),
        ),
    );
  }
}
