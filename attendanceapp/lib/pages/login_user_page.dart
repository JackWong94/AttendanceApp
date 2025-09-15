import 'package:flutter/material.dart';
import 'package:attendanceapp/widgets/camera_placeholder.dart';
import 'package:attendanceapp/pages/register_user_page.dart';
import 'package:attendanceapp/services/camera_service.dart';
import 'package:attendanceapp/services/face_model_service.dart';
import 'package:attendanceapp/services/face_recognition_service.dart';
import 'package:camera/camera.dart';

class LoginUserPage extends StatefulWidget {
  const LoginUserPage({super.key});

  @override
  State<LoginUserPage> createState() => _LoginUserPageState();
}

class _LoginUserPageState extends State<LoginUserPage> {

  final CameraService _cameraService = CameraService(); // ✅ use singleton

  @override
  void initState() {
    super.initState();
    _cameraService.initCamera(); // ✅ initialize camera once
  }

  @override
  void dispose() {
    // ✅ do NOT dispose controller here; managed by CameraService
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Attendance App")),
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
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const RegisterUserPage(),
                      ),
                    );
                  },
                  child: const Text("Register New User"),
                ),
                const SizedBox(height: 12), // ✅ spacing between buttons
                ElevatedButton.icon(
                  onPressed: () async {
                    try {
                      final picture = await CameraService().controller!.takePicture();
                      final bytes = await picture.readAsBytes();

                      final user = await FaceRecognitionService.recognizeUser(bytes);

                      if (user != null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text("✅ Welcome back, $user!")),
                        );
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("❌ Face not recognized")),
                        );
                      }
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text("Error: $e")),
                      );
                    }
                  },
                  icon: const Icon(Icons.face_retouching_natural),
                  label: const Text("Scan Face"),
                ),
              ],
            ),
          ),
          // Camera Preview
          Expanded(
            child: _cameraService.controller == null
                ? const CameraPlaceholder(
              message: "Camera not available on this platform",
            )
                : FutureBuilder<void>(
              future: _cameraService.initializeFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.done) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24.0,
                        vertical: 24.0,
                      ),
                      child: AspectRatio(
                        aspectRatio:
                        _cameraService.controller!.value.aspectRatio,
                        child:
                        CameraPreview(_cameraService.controller!), // ✅ use shared controller
                      ),
                    ),
                  );
                } else {
                  return const Center(
                    child: CircularProgressIndicator(),
                  );
                }
              },
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
