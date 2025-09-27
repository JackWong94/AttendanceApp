import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:attendanceapp/services/camera_service.dart';
import 'package:attendanceapp/services/user_model_service.dart';
import 'package:attendanceapp/services/attendance_model_service.dart';
import 'package:attendanceapp/models/user_model.dart';
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

    for (var u in _users) {
      _isEditing[u.id] = false;
      _isRecapturing[u.id] = false;
      capturedPhotos[u.id] = [];
      capturedEmbeddings[u.id] = [];
      _nameControllers[u.id] = TextEditingController(text: u.name);
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

  Future<void> _startRecapture(UserModel user) async {
    capturedPhotos[user.id] = [];
    capturedEmbeddings[user.id] = [];
    setState(() => _isRecapturing[user.id] = true);

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => WillPopScope(
        onWillPop: () async => false,
        child: StatefulBuilder(
          builder: (context, setOverlayState) {
            return Scaffold(
              backgroundColor: Colors.black.withOpacity(0.7),
              body: SafeArea(
                child: Center(
                  child: Container(
                    margin: const EdgeInsets.all(16),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          "Recapture Face for ${user.name}",
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 18),
                        ),
                        const SizedBox(height: 16),

                        // Only widget shows previews
                        FaceCaptureWidget(
                          cameraService: _cameraService,
                          onCompleted: (photos, embeddings) {
                            setOverlayState(() {
                              capturedPhotos[user.id] = photos;
                              capturedEmbeddings[user.id] = embeddings;
                            });
                          },
                        ),

                        const SizedBox(height: 16),

                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            ElevatedButton(
                              onPressed: () {
                                setState(() => _isRecapturing[user.id] = false);
                                Navigator.of(context).pop();
                              },
                              style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.grey),
                              child: const Text("Cancel"),
                            ),
                            ElevatedButton(
                              onPressed: capturedEmbeddings[user.id]!.length == 3
                                  ? () async {
                                final updatedUser = user.copyWith(
                                  faceEmbeddings: capturedEmbeddings[user.id],
                                  embedding: capturedEmbeddings[user.id]!.first,
                                );
                                await _userService.addUser(updatedUser);

                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text("User embeddings updated!")),
                                );

                                setState(() => _isRecapturing[user.id] = false);
                                Navigator.of(context).pop();
                                await _loadUsers();
                              }
                                  : null,
                              child: const Text("OK"),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildUserCard(UserModel user, int index) {
    final isEditing = _isEditing[user.id] ?? false;

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
