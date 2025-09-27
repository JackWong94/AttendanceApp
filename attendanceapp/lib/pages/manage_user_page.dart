import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:attendanceapp/services/camera_service.dart';
import 'package:attendanceapp/services/user_model_service.dart';
import 'package:attendanceapp/services/attendance_model_service.dart';
import 'package:attendanceapp/models/user_model.dart';
import 'package:attendanceapp/widgets/camera_placeholder.dart';
import 'package:attendanceapp/services/web_face_api.dart' as webFaceApi;

class ManageUserPage extends StatefulWidget {
  const ManageUserPage({super.key});

  @override
  State<ManageUserPage> createState() => _ManageUserPageState();
}

class _ManageUserPageState extends State<ManageUserPage> {
  final UserModelService _userService = UserModelService.instance;
  final CameraService _cameraService = CameraService();

  List<UserModel> _users = [];
  bool _isLoading = true;

  final Map<String, bool> _isEditing = {};
  final Map<String, bool> _isRecapturing = {};
  final Map<String, List<Uint8List>> capturedPhotos = {};
  final Map<String, List<List<double>>> capturedEmbeddings = {};
  final Map<String, TextEditingController> _nameControllers = {};
  final Map<String, int> _captureStep = {};

  @override
  void initState() {
    super.initState();
    _loadUsers();
    _cameraService.initCamera(forceReinitOnWeb: true).then((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    for (var ctrl in _nameControllers.values) {
      ctrl.dispose();
    }
    super.dispose();
  }

  Future<void> _loadUsers() async {
    setState(() => _isLoading = true);
    _users = await _userService.getAllUsers();
    _isEditing.clear();
    _isRecapturing.clear();
    capturedPhotos.clear();
    capturedEmbeddings.clear();
    _nameControllers.clear();
    _captureStep.clear();

    for (var u in _users) {
      _isEditing[u.id] = false;
      _isRecapturing[u.id] = false;
      capturedPhotos[u.id] = [];
      capturedEmbeddings[u.id] = [];
      _nameControllers[u.id] = TextEditingController(text: u.name);
      _captureStep[u.id] = 0;
    }
    setState(() => _isLoading = false);
  }

  void _toggleEdit(String userId) {
    setState(() => _isEditing[userId] = !(_isEditing[userId] ?? false));
  }

  Future<void> _updateUserName(UserModel user, String newName) async {
    if (newName.trim().isEmpty) return;
    final updatedUser = user.copyWith(name: newName.trim());
    await _userService.addUser(updatedUser);
    await _loadUsers();
  }

  Future<void> _startRecapture(UserModel user) async {
    setState(() {
      _isRecapturing[user.id] = true;
      capturedPhotos[user.id] = [];
      capturedEmbeddings[user.id] = [];
      _captureStep[user.id] = 0;
    });
  }

  Future<void> _captureFaceStep(UserModel user) async {
    if (!_cameraService.isInitialized) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Camera not ready")),
      );
      return;
    }

    final steps = ["Look straight", "Turn LEFT", "Turn RIGHT"];

    if (_captureStep[user.id]! >= steps.length) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("All 3 steps completed")),
      );
      return;
    }

    try {
      final picture = await _cameraService.controller!.takePicture();
      final bytes = await picture.readAsBytes();

      final img = await webFaceApi.uint8ListToImage(bytes);
      final resizedImg = await webFaceApi.resizeImage(img, 160, 160);
      final descriptor = await webFaceApi.computeFaceDescriptorSafe(resizedImg);

      if (descriptor.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("No face detected. Please try again.")),
        );
        return;
      }

      capturedPhotos[user.id]!.add(bytes);
      capturedEmbeddings[user.id]!.add(descriptor);
      setState(() {
        _captureStep[user.id] = _captureStep[user.id]! + 1;
      });

      if (_captureStep[user.id]! == steps.length) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("✅ 3 photos captured successfully!")),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error capturing photo: $e")),
      );
    }
  }

  Future<void> _updateEmbeddings(UserModel user) async {
    if (capturedEmbeddings[user.id]!.length != 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please capture 3 valid photos")),
      );
      return;
    }

    final updatedUser = user.copyWith(
      faceEmbeddings: capturedEmbeddings[user.id],
      embedding: capturedEmbeddings[user.id]!.first,
    );
    await _userService.addUser(updatedUser);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("User embeddings updated!")),
    );
    setState(() => _isRecapturing[user.id] = false);
    await _loadUsers();
  }

  Future<void> _cancelRecapture(String userId) async {
    capturedPhotos[userId] = [];
    capturedEmbeddings[userId] = [];
    _captureStep[userId] = 0;
    setState(() => _isRecapturing[userId] = false);
  }

  Future<void> _deleteUser(UserModel user) async {
    final confirm = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text("Delete User"),
        content: const Text(
            "Are you sure you want to delete this user? All attendance records will also be deleted."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Delete", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await AttendanceModelService.instance.deleteAllAttendanceForUser(user.id);
      await UserModelService.instance.deleteUser(user.id);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("User and attendance deleted successfully!")),
      );

      await _loadUsers();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error deleting user: $e")),
      );
    }
  }

  Widget _buildUserCard(UserModel user, int index) {
    final isEditing = _isEditing[user.id] ?? false;
    final isRecapturing = _isRecapturing[user.id] ?? false;
    final steps = ["Look straight", "Turn LEFT", "Turn RIGHT"];

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          children: [
            // Name row with Edit & Delete
            Row(
              children: [
                Text("${index + 1}.", style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: isEditing
                      ? TextField(
                    controller: _nameControllers[user.id],
                    decoration: const InputDecoration(labelText: "Name"),
                  )
                      : Text(user.name, style: const TextStyle(fontSize: 16)),
                ),
                IconButton(
                  icon: Icon(isEditing ? Icons.save : Icons.edit, color: Colors.blue),
                  onPressed: () {
                    if (isEditing) {
                      _updateUserName(user, _nameControllers[user.id]!.text);
                    }
                    _toggleEdit(user.id);
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.delete),
                  onPressed: () => _deleteUser(user),
                ),
              ],
            ),

            const SizedBox(height: 8),

            if (isRecapturing)
              Column(
                children: [
                  if (_captureStep[user.id]! < steps.length)
                    Text(
                      "Step ${_captureStep[user.id]! + 1}/${steps.length}: ${steps[_captureStep[user.id]!]}",
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    )
                  else
                    const Text("All 3 steps completed!", style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      ElevatedButton.icon(
                        onPressed: () => _captureFaceStep(user),
                        icon: const Icon(Icons.videocam),
                        label: const Text("Capture Step"),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        onPressed: () => _updateEmbeddings(user),
                        icon: const Icon(Icons.save),
                        label: const Text("Update Embeddings"),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        onPressed: () => _cancelRecapture(user.id),
                        icon: const Icon(Icons.cancel),
                        label: const Text("Cancel"),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.grey),
                      ),
                    ],
                  ),
                  if (capturedPhotos[user.id]!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Wrap(
                        spacing: 4,
                        children: capturedPhotos[user.id]!
                            .map((bytes) => Image.memory(bytes,
                            width: 80, height: 80, fit: BoxFit.cover))
                            .toList(),
                      ),
                    ),
                ],
              )
            else
              ElevatedButton.icon(
                onPressed: () => _startRecapture(user),
                icon: const Icon(Icons.videocam),
                label: const Text("Recapture Face"),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Manage Users")),
      body: Column(
        children: [
          // Camera always fixed on top
          SizedBox(
            height: 250,
            child: _cameraService.controller != null &&
                _cameraService.controller!.value.isInitialized
                ? CameraPreview(_cameraService.controller!)
                : const CameraPlaceholder(message: "Camera not ready"),
          ),

          // User list scrolls below camera
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _users.length,
              itemBuilder: (context, index) {
                final user = _users[index];
                return _buildUserCard(user, index);
              },
            ),
          ),
        ],
      ),
    );
  }
}
