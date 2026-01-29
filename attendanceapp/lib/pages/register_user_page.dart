import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:attendanceapp/services/camera_service.dart';
import 'package:attendanceapp/services/face_model_service.dart';
import 'package:attendanceapp/services/user_model_service.dart';
import 'package:attendanceapp/services/image_model_service.dart';
import 'package:attendanceapp/models/user_model.dart';
import 'package:attendanceapp/pages/login_user_page.dart';
import 'package:attendanceapp/widgets/face_capture_widget.dart';
import 'package:attendanceapp/services/non_admin_authentication_service.dart';

class RegisterUserPage extends StatefulWidget {
  const RegisterUserPage({super.key});

  @override
  State<RegisterUserPage> createState() => _RegisterUserPageState();
}

class _RegisterUserPageState extends State<RegisterUserPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final CameraService _cameraService = CameraService.instance; // ✅ fixed
  final UserModelService _userService = UserModelService.instance;
  final _authService = NonAdminAuthenticationService.instance;

  List<Uint8List> capturedPhotos = [];
  List<List<double>> capturedEmbeddings = [];
  bool _isCreating = false;
  bool _obscurePassword = true;

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
    _passwordController.dispose();
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

  void _onFaceCaptureCompleted(
      List<Uint8List> photos, List<List<double>> embeddings) {
    setState(() {
      capturedPhotos = photos;
      capturedEmbeddings = embeddings;
    });

    if (capturedEmbeddings.length == 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("✅ Face successfully recorded!")),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
          Text("Only ${capturedEmbeddings.length}/3 valid photos recorded"),
        ),
      );
    }
  }

  Future<void> _registerUser() async {
    if (_isCreating) return;
    if (!_formKey.currentState!.validate()) return;

    final name = _nameController.text.trim();
    final password = _passwordController.text;

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
      );

      await _userService.addUser(user);
      // Save password using shared auth service
      if (password.isNotEmpty) {
        await _authService.changePassword(
          userId: employeeId,
          plainPassword: password,
        );
      }
      await FaceModelService.reload();

      await ImageModelService.instance.saveCapturedPhotos(
        employeeId: employeeId,
        photos: capturedPhotos,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("User registered successfully!")),
      );

      Navigator.pop(context);
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
                  // Replaced manual capture sequence with FaceCaptureWidget
                  FaceCaptureWidget(
                    cameraService: _cameraService,
                    onCompleted: _onFaceCaptureCompleted,
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
                          validator: (v) =>
                          v == null || v.isEmpty ? "Enter name" : null,
                        ),
                        const SizedBox(height: 16),

                        TextFormField(
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          decoration: InputDecoration(
                            labelText: "Password",
                            border: const OutlineInputBorder(),
                            hintText: "Input Password",
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword ? Icons.visibility_off : Icons.visibility,
                              ),
                              onPressed: () {
                                setState(() {
                                  _obscurePassword = !_obscurePassword;
                                });
                              },
                            ),
                          ),
                          validator: (value) =>
                              _authService.validatePassword(value ?? ""),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      ElevatedButton.icon(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.cancel),
                        label: const Text("Cancel"),
                        style:
                        ElevatedButton.styleFrom(backgroundColor: Colors.grey),
                      ),
                      ElevatedButton.icon(
                        onPressed: _registerUser,
                        icon: const Icon(Icons.save),
                        label: const Text("Save User"),
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
