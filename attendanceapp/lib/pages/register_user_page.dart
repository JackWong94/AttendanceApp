import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:attendanceapp/widgets/camera_placeholder.dart';
import 'package:attendanceapp/services/camera_service.dart';
import 'package:camera/camera.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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

  List<Uint8List> capturedPhotos = []; // store 3 captured images

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

  /// Capture 3 photos (center, left, right)
  Future<void> _captureFaceSequence() async {
    capturedPhotos.clear();

    final steps = [
      {"instruction": "Look straight ahead", "angle": "center"},
      {"instruction": "Turn your head to the LEFT", "angle": "left"},
      {"instruction": "Turn your head to the RIGHT", "angle": "right"},
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Face recording complete!")),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Only ${capturedPhotos.length}/3 photos captured")),
      );
    }

    setState(() {});
  }

  /// Save user data + images to Firestore
  Future<void> _registerUser() async {
    if (_formKey.currentState!.validate()) {
      final name = _nameController.text;
      final email = _emailController.text;
      final id = _idController.text;

      try {
        await FirebaseFirestore.instance.collection('users').add({
          'name': name,
          'email': email,
          'employeeId': id,
          'createdAt': FieldValue.serverTimestamp(),
          // You can later add image uploads to Firebase Storage here
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("User registered successfully")),
        );

        Navigator.pop(context); // go back after saving
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error saving user: $e")),
        );
      }
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
                  if (snapshot.connectionState ==
                      ConnectionState.done) {
                    return AspectRatio(
                      aspectRatio:
                      _cameraService.controller!.value.aspectRatio,
                      child:
                      CameraPreview(_cameraService.controller!),
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

            // Form
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
                    validator: (value) =>
                    value == null || value.isEmpty ? "Enter name" : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _emailController,
                    decoration: const InputDecoration(
                      labelText: "Email",
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) => value == null || !value.contains("@")
                        ? "Enter valid email"
                        : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _idController,
                    decoration: const InputDecoration(
                      labelText: "Employee ID",
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) =>
                    value == null || value.isEmpty ? "Enter ID" : null,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Face recording button
            ElevatedButton.icon(
              onPressed: _captureFaceSequence,
              icon: const Icon(Icons.videocam),
              label: const Text("Record Face (3 Photos)"),
            ),
            const SizedBox(height: 16),

            // Preview captured thumbnails
            if (capturedPhotos.isNotEmpty)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: capturedPhotos
                    .map((bytes) => Padding(
                  padding: const EdgeInsets.all(4.0),
                  child: Image.memory(bytes,
                      width: 80, height: 80, fit: BoxFit.cover),
                ))
                    .toList(),
              ),

            const SizedBox(height: 24),

            // Save & Cancel
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
                    Navigator.pop(context);
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
      ),
    );
  }
}
