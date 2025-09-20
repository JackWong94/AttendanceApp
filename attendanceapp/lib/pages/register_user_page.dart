import 'dart:async';
import 'dart:typed_data';
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
  final CameraService _cameraService = CameraService();
  final UserModelService _userService = UserModelService.instance;

  List<Uint8List> capturedPhotos = [];
  List<List<double>> capturedEmbeddings = [];
  bool _isCreating = false;

  bool _cameraTimedOut = false;
  Timer? _cameraTimer;

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  @override
  void dispose() {
    _cameraTimer?.cancel();
    _nameController.dispose();
    super.dispose();
  }

  /// Initialize camera with 1-minute fallback
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

  Future<String> _generateUniqueEmployeeId() async {
    int counter = 1;
    String newId;
    do {
      newId = "EMP${counter.toString().padLeft(4, '0')}";
      final exists = await _userService.isEmployeeIdExists(newId);
      if (!exists) break;
      counter++;
    } while (true);
    return newId;
  }

  Future<void> _captureFaceSequence() async {
    if (_isCreating) return;

    capturedPhotos.clear();
    capturedEmbeddings.clear();

    final steps = [
      {"instruction": "Look straight ahead"},
      {"instruction": "Slightly turn your head to the LEFT"},
      {"instruction": "Slightly turn your head to the RIGHT"},
    ];

    for (var i = 0; i < steps.length; i++) {
      final step = steps[i];
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
          if (!_cameraService.isInitialized) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Camera not ready")),
            );
            return;
          }

          final picture = await _cameraService.controller!.takePicture();
          final bytes = await picture.readAsBytes();
          capturedPhotos.add(bytes);

          final img = await webFaceApi.uint8ListToImage(bytes);
          final resizedImg = await webFaceApi.resizeImage(img, 160, 160);
          final descriptor =
          await webFaceApi.computeFaceDescriptorSafe(resizedImg);

          if (descriptor.isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text("No face detected in photo #${i + 1}")),
            );
          } else {
            capturedEmbeddings.add(descriptor);
          }
        } catch (e) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Error capturing photo: $e")),
          );
        }
      }
    }

    if (capturedEmbeddings.length == 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("✅ Face successfully recorded!")),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                "Only ${capturedEmbeddings.length}/3 valid photos recorded")),
      );
    }

    setState(() {});
  }

  Future<void> _registerUser() async {
    if (_isCreating) return;
    if (!_formKey.currentState!.validate()) return;

    final name = _nameController.text.trim();

    if (capturedEmbeddings.length != 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please record all 3 face photos.")),
      );
      return;
    }

    setState(() => _isCreating = true);

    try {
      if (await _userService.isNameExists(name)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Name already exists. Please change it.")),
        );
        setState(() => _isCreating = false);
        return;
      }

      final employeeId = await _generateUniqueEmployeeId();

      final user = UserModel(
        id: employeeId,
        name: name,
        employeeId: employeeId,
        faceEmbeddings: capturedEmbeddings,
        embedding: capturedEmbeddings.first,
      );

      await _userService.addUser(user);
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
    } finally {
      setState(() => _isCreating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        AbsorbPointer(
          absorbing: _isCreating,
          child: Scaffold(
            appBar: AppBar(title: const Text("Register New User")),
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  SizedBox(
                    height: 250,
                    child: FutureBuilder<void>(
                      future: _cameraService.initializeFuture,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          // Still initializing → show spinner
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
                          // Camera still null/unavailable → show spinner unless timeout
                          return !_cameraTimedOut
                              ? const Center(child: CircularProgressIndicator())
                              : const CameraPlaceholder(
                            message: "Camera not available on this platform",
                          );
                        }
                      },
                    ),
                  ),
                  const SizedBox(height: 24),
                  Form(
                    key: _formKey,
                    child: TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: "Full Name",
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) =>
                      value == null || value.isEmpty ? "Enter name" : null,
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
                        child: Image.memory(bytes,
                            width: 80, height: 80, fit: BoxFit.cover),
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
                          MaterialPageRoute(
                              builder: (_) => const LoginUserPage()),
                        ),
                        icon: const Icon(Icons.cancel),
                        label: const Text("Cancel"),
                        style:
                        ElevatedButton.styleFrom(backgroundColor: Colors.grey),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
        if (_isCreating)
          Container(
            color: Colors.black.withOpacity(0.5),
            child: const Center(
              child: CircularProgressIndicator(),
            ),
          ),
      ],
    );
  }
}
