import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:attendanceapp/widgets/camera_placeholder.dart';
import 'package:attendanceapp/services/camera_service.dart';
import 'package:attendanceapp/pages/login_user_page.dart';
import 'package:camera/camera.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:attendanceapp/services/web_face_api.dart' as webFaceApi;
import 'dart:convert'; // ✅ for jsonEncode / jsonDecode
import 'dart:html' as html;

class RegisterUserPage extends StatefulWidget {
  const RegisterUserPage({super.key});

  @override
  State<RegisterUserPage> createState() => _RegisterUserPageState();
}

class _RegisterUserPageState extends State<RegisterUserPage> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _idController = TextEditingController();

  final CameraService _cameraService = CameraService();
  List<Uint8List> capturedPhotos = [];

  @override
  void initState() {
    super.initState();
    _cameraService.initCamera();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _idController.dispose();
    super.dispose();
  }

  Future<void> _captureFaceSequence() async {
    capturedPhotos.clear();

    final steps = [
      {"instruction": "Look straight ahead", "angle": "center"},
      {"instruction": "Slightly turn your head to the LEFT", "angle": "left"},
      {"instruction": "Slightly turn your head to the RIGHT", "angle": "right"},
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
      // 🔹 Compute embeddings automatically after capturing all 3 photos
      try {
        final embeddings = await _computeEmbeddings();
      } catch (e) {
        print("Error computing embeddings: $e");
      }

    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Only ${capturedPhotos.length}/3 photos captured")),
      );
    }

    setState(() {});
  }

  /// Compute embeddings for captured photos with retry logic
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
          // Step 1: Load image
          final img = await webFaceApi.uint8ListToImage(bytes);

          // Step 2: Resize image
          final resizedImg = await webFaceApi.resizeImage(img, 160, 160);

          // Step 3: Compute descriptor safely
          descriptor = await webFaceApi.computeFaceDescriptorSafe(resizedImg);

          if (descriptor.isEmpty) {
            throw Exception("No face detected in photo #$i");
          }

          success = true;
          break; // Exit retry loop on success
        } catch (e) {
          print("Attempt $attempt: Failed to compute descriptor for photo #$i: $e");
          if (attempt < retries) await Future.delayed(Duration(milliseconds: delayMs));
        }
      }

      if (success && descriptor != null) {
        embeddings.add(descriptor);
        print("Successfully computed embedding for photo #$i");
      } else {
        print("Failed to compute embedding for photo #$i after $retries attempts.");
        allSuccess = false;
      }
    }
    if (allSuccess) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("✅ Face Succefully Registered! ")),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("❌ Not Succesfully Registered! Please Retry!")),
      );
    }
    return embeddings;
  }

  Future<void> _registerUser() async {
    if (!_formKey.currentState!.validate()) return;

    final name = _nameController.text;
    final email = _emailController.text;
    final id = _idController.text;

    try {
      // Compute embeddings
      List<List<double>> embeddings = await _computeEmbeddings();
      // Convert each descriptor (List<double>) to JSON string
      final embeddingsForFirestore = embeddings
          .map((descriptor) => jsonEncode(descriptor))
          .toList();
      // Save user with embeddings in same document
      await FirebaseFirestore.instance.collection('users').add({
        'name': name,
        'email': email,
        'employeeId': id,
        'faceEmbeddings': embeddingsForFirestore, // store embeddings here
        'createdAt': FieldValue.serverTimestamp(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("User registered successfully")),
      );

      Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => const LoginUserPage()
          ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error saving user: $e")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Register New User")),
      body: _buildForm(),
    );
  }

  /// Extract your current Column + Form into a separate method for clarity
  Widget _buildForm() {
    return SingleChildScrollView(
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
                if (snapshot.connectionState == ConnectionState.done) {
                  return AspectRatio(
                    aspectRatio: _cameraService.controller!.value.aspectRatio,
                    child: CameraPreview(_cameraService.controller!),
                  );
                } else {
                  return const Center(child: CircularProgressIndicator());
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
                  controller: _emailController,
                  decoration: const InputDecoration(
                    labelText: "Email",
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) => value == null || !value.contains("@") ? "Enter valid email" : null,
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
                onPressed: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const LoginUserPage(),
                    ),
                  );
                },
                icon: const Icon(Icons.cancel),
                label: const Text("Cancel"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}