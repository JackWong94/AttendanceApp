import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:attendanceapp/services/camera_service.dart';
import 'package:attendanceapp/services/user_model_service.dart';
import 'package:attendanceapp/services/attendance_model_service.dart';
import 'package:attendanceapp/models/user_model.dart';
import 'package:attendanceapp/widgets/camera_placeholder.dart';
import 'package:attendanceapp/widgets/face_capture_widget.dart';

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

    // Show overlay with FaceCaptureWidget
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        content: FaceCaptureWidget(
          cameraService: _cameraService,
          onCompleted: (photos, embeddings) {
            capturedPhotos[user.id] = photos;
            capturedEmbeddings[user.id] = embeddings;
            setState(() {});
          },
        ),
        actions: [
          TextButton(
            onPressed: () {
              _isRecapturing[user.id] = false;
              Navigator.pop(context);
              setState(() {});
            },
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () {
              if (capturedEmbeddings[user.id]!.length != 3) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Please capture all 3 valid photos")),
                );
                return;
              }
              final updatedUser = user.copyWith(
                faceEmbeddings: capturedEmbeddings[user.id],
                embedding: capturedEmbeddings[user.id]!.first,
              );
              _userService.addUser(updatedUser).then((_) {
                _isRecapturing[user.id] = false;
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("User embeddings updated!")),
                );
                setState(() {});
              });
            },
            child: const Text("Update"),
          ),
        ],
      ),
    );
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

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Row(
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
            IconButton(
              icon: const Icon(Icons.face, color: Colors.green),
              tooltip: "Recapture Face",
              onPressed: () => _startRecapture(user),
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
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _users.length,
        itemBuilder: (context, index) {
          final user = _users[index];
          return _buildUserCard(user, index);
        },
      ),
    );
  }
}
