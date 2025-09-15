import 'package:flutter/material.dart';
import 'package:attendanceapp/widgets/camera_placeholder.dart';
import 'package:attendanceapp/pages/register_user_page.dart';
import 'package:attendanceapp/services/camera_service.dart';
import 'package:attendanceapp/services/face_model_service.dart';
import 'package:attendanceapp/services/face_recognition_service.dart';
import 'package:attendanceapp/services/attendance_service.dart';
import 'package:attendanceapp/pages/attendance_page.dart';
import 'package:camera/camera.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class LoginUserPage extends StatefulWidget {
  const LoginUserPage({super.key});

  @override
  State<LoginUserPage> createState() => _LoginUserPageState();
}

class _LoginUserPageState extends State<LoginUserPage> {
  final CameraService _cameraService = CameraService();
  final AttendanceService _attendanceService = AttendanceService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();
    CameraService().initCamera(forceReinitOnWeb: true).then((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    // ✅ do NOT dispose controller here; managed by CameraService
    super.dispose();
  }

  Future<void> _handleScan({required bool isScanIn}) async {
    try {
      // 1️⃣ Take picture
      final picture = await _cameraService.controller!.takePicture();
      final bytes = await picture.readAsBytes();

      // 2️⃣ Recognize user
      final userId = await FaceRecognitionService.recognizeUser(bytes);

      if (userId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("❌ Face not recognized")),
        );
        return;
      }

      // 3️⃣ Get user reference from users collection
      final userRef = _firestore.collection('users').doc(userId);

      // 4️⃣ Scan with rules
      await _attendanceService.scanUser(userRef: userRef, isScanIn: isScanIn);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              "✅ $userId ${isScanIn ? 'scanned in' : 'scanned out'} successfully"),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Attendance App"),
      ),

      // ✅ Drawer menu
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
                Navigator.pop(context); // close drawer
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const RegisterUserPage()),
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
                  MaterialPageRoute(builder: (context) => const AttendancePage()),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text("Log out"),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => const LoginUserPage()),
                );
              },
            ),
          ],
        ),
      ),

      body: Column(
        children: [
          // Title + button
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                const Text(
                  "Welcome! Please scan to login/logout",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 30),

                // ✅ Row of two buttons
                Row(
                  mainAxisSize: MainAxisSize.min, // makes the row wrap tightly around its children
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


          // Camera Preview
          Expanded(
            child: Center(
              child: _cameraService.controller == null
                  ? const CameraPlaceholder(
                message: "Camera not available on this platform",
              )
                  : FutureBuilder<void>(
                future: _cameraService.initializeFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.done &&
                      _cameraService.controller!.value.isInitialized) {
                    return Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: AspectRatio(
                        aspectRatio: _cameraService.controller!.value.aspectRatio,
                        child: CameraPreview(_cameraService.controller!),
                      ),
                    );
                  } else {
                    return const CircularProgressIndicator();
                  }
                },
              ),
            ),
          ),

          ElevatedButton.icon(
            onPressed: () async {
              try {
                await FaceModelService.reload();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("✅ Face models reloaded successfully")),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text("❌ Failed to reload models: $e")),
                );
              }
            },
            icon: const Icon(Icons.refresh),
            label: const Text("Refresh Face Models"),
          ),
        ],
      ),
    );
  }
}
