import 'dart:typed_data';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:attendanceapp/services/camera_service.dart';
import 'package:attendanceapp/services/face_model_service.dart';
import 'package:attendanceapp/services/user_model_service.dart';
import 'package:attendanceapp/models/user_model.dart';
import 'package:attendanceapp/pages/login_user_page.dart';
import 'package:attendanceapp/widgets/camera_placeholder.dart';
import 'package:attendanceapp/services/web_face_api.dart' as webFaceApi;

class RegisterUserPage extends StatefulWidget {
  const RegisterUserPage({super.key});

  @override
  State<RegisterUserPage> createState() => _RegisterUserPageState();
}

class _RegisterUserPageState extends State<RegisterUserPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _idController = TextEditingController();
  final TextEditingController _emailController = TextEditingController(); // NEW
  final CameraService _cameraService = CameraService();
  final UserModelService _userService = UserModelService();

  List<Uint8List> capturedPhotos = [];

  @override
  void initState() {
    super.initState();
    _cameraService.initCamera(forceReinitOnWeb: true).then((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _idController.dispose();
    _emailController.dispose(); // dispose email controller
    super.dispose();
  }

  Future<void> _captureFaceSequence() async {
    capturedPhotos.clear();
    final steps = [
      {"instruction": "Look straight ahead"},
      {"instruction": "Slightly turn your head to the LEFT"},
      {"instruction": "Slightly turn your head to the RIGHT"},
    ];

    for (var step in steps) {
      final confirmed = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (_) => AlertDialog(
          title: const Text("Face Recording"),
          content: Text(step["instruction"]!),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text("Capture"),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text("Skip"),
            ),
          ],
        ),
      );

      if (confirmed == true) {
        try {
          final XFile picture = await _cameraService.controller!.takePicture();
          final bytes = await picture.readAsBytes();
          capturedPhotos.add(bytes);
        } catch (e) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Error capturing photo: $e")),
          );
        }
      }
    }

    if (capturedPhotos.length == 3) {
      print("Face recording complete!");
      await _computeEmbeddings();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Only ${capturedPhotos.length}/3 photos captured")),
      );
    }

    setState(() {});
  }

  Future<List<List<double>>> _computeEmbeddings({
    int retries = 3,
    int delayMs = 500,
  }) async {
    List<List<double>> embeddings = [];
    bool allSuccess = true;

    for (var i = 0; i < capturedPhotos.length; i++) {
      final bytes = capturedPhotos[i];
      bool success = false;
      List<double>? descriptor;

      for (int attempt = 1; attempt <= retries; attempt++) {
        try {
          final img = await webFaceApi.uint8ListToImage(bytes);
          final resizedImg = await webFaceApi.resizeImage(img, 160, 160);
          descriptor = await webFaceApi.computeFaceDescriptorSafe(resizedImg);

          if (descriptor.isEmpty) throw Exception("No face detected in photo #$i");
          success = true;
          break;
        } catch (e) {
          print("Attempt $attempt: Failed photo #$i: $e");
          if (attempt < retries) await Future.delayed(Duration(milliseconds: delayMs));
        }
      }

      if (success && descriptor != null) {
        embeddings.add(descriptor);
      } else {
        allSuccess = false;
      }
    }

    if (allSuccess) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("✅ Face successfully recorded!")),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("❌ Failed to record face. Please retry!")),
      );
    }

    return embeddings;
  }

  Future<void> _registerUser() async {
    if (!_formKey.currentState!.validate()) return;

    final name = _nameController.text.trim();
    final id = _idController.text.trim();
    final email = _emailController.text.trim(); // take from input

    if (capturedPhotos.length != 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please capture all 3 face photos.")),
      );
      return;
    }

    try {
      List<List<double>> embeddings = await _computeEmbeddings();
      final primaryEmbedding = embeddings.first;

      final employeeId = id;

      final user = UserModel(
        id: id,
        name: name,
        email: email,           // required
        employeeId: employeeId, // required
        faceEmbeddings: embeddings,
        embedding: primaryEmbedding,
      );

      await _userService.addUser(user);

      // Reload global face embeddings
      await FaceModelService.reload();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("User registered successfully!")),
      );

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginUserPage()),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error registering user: $e")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Register New User")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            SizedBox(
              height: 250,
              child: _cameraService.controller == null
                  ? const CameraPlaceholder(
                message: "Camera not available on this platform",
              )
                  : FutureBuilder<void>(
                future: _cameraService.initializeFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.done &&
                      _cameraService.controller != null &&
                      _cameraService.controller!.value.isInitialized) {
                    return AspectRatio(
                      aspectRatio: _cameraService.controller!.value.aspectRatio,
                      child: CameraPreview(_cameraService.controller!),
                    );
                  } else if (snapshot.hasError) {
                    return CameraPlaceholder(
                      message: "Camera error: ${snapshot.error}",
                    );
                  } else {
                    return const Center(
                      child: CircularProgressIndicator(),
                    );
                  }
                },
              ),
            ),
            const SizedBox(height: 24),
            Form(
              key: _formKey,
              child: Column(
                children: [
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: "Full Name",
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) => value == null || value.isEmpty ? "Enter name" : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _emailController, // NEW
                    decoration: const InputDecoration(
                      labelText: "Email",
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) =>
                    value == null || !value.contains("@") ? "Enter valid email" : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _idController,
                    decoration: const InputDecoration(
                      labelText: "Employee ID",
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) => value == null || value.isEmpty ? "Enter ID" : null,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _captureFaceSequence,
              icon: const Icon(Icons.videocam),
              label: const Text("Record Face (3 Photos)"),
            ),
            const SizedBox(height: 16),
            if (capturedPhotos.isNotEmpty)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: capturedPhotos
                    .map((bytes) => Padding(
                  padding: const EdgeInsets.all(4.0),
                  child: Image.memory(bytes, width: 80, height: 80, fit: BoxFit.cover),
                ))
                    .toList(),
              ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton.icon(
                  onPressed: _registerUser,
                  icon: const Icon(Icons.save),
                  label: const Text("Save User"),
                ),
                ElevatedButton.icon(
                  onPressed: () => Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (_) => const LoginUserPage()),
                  ),
                  icon: const Icon(Icons.cancel),
                  label: const Text("Cancel"),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.grey),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
