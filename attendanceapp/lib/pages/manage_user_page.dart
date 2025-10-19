import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:attendanceapp/services/camera_service.dart';
import 'package:attendanceapp/services/user_model_service.dart';
import 'package:attendanceapp/services/attendance_model_service.dart';
import 'package:attendanceapp/services/face_model_service.dart'; // ✅ added
import 'package:attendanceapp/models/user_model.dart';
import 'package:attendanceapp/widgets/face_capture_widget.dart';
import '../main.dart'; // routeObserver

class ManageUserPage extends StatefulWidget {
  const ManageUserPage({super.key});

  @override
  State<ManageUserPage> createState() => _ManageUserPageState();
}

class _ManageUserPageState extends State<ManageUserPage> with RouteAware {
  final UserModelService _userService = UserModelService.instance;
  final CameraService _cameraService = CameraService.instance; // ✅ singleton

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
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    routeObserver.subscribe(this, ModalRoute.of(context)!);
  }

  @override
  void dispose() {
    for (var ctrl in _nameControllers.values) {
      ctrl.dispose();
    }
    routeObserver.unsubscribe(this);
    super.dispose();
  }

  @override
  void didPopNext() {
    // 🔥 only reinit when coming back
    if (!_cameraService.isInitialized) {
      _initCamera();
    }
  }

  void _initCamera() {
    _cameraService.initCamera(forceReinitOnWeb: true);
    if (mounted) setState(() {});
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

  Future<void> _startRecapture(UserModel user) async {
    // Always clean up before reinit
    await _cameraService.disposeCamera();
    await _cameraService.initCamera(forceReinitOnWeb: true);

    if (!_cameraService.isInitialized) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("⚠️ Camera failed to initialize")),
      );
      return;
    }

    _isRecapturing[user.id] = true;
    capturedPhotos[user.id] = [];
    capturedEmbeddings[user.id] = [];

    // Show face capture dialog first
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => FaceCaptureDialog(
        cameraService: _cameraService,
        onCompleted: (photos, embeddings) {
          capturedPhotos[user.id] = photos;
          capturedEmbeddings[user.id] = embeddings;
        },
      ),
    );

    // If not all 3 embeddings, show warning
    if (capturedEmbeddings[user.id]!.length != 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("❌ Please capture all 3 valid photos")),
      );
      _isRecapturing[user.id] = false;
      setState(() {});
      return;
    }

    // Show overlay loader while updating embeddings
    showDialog(
      context: context,
      barrierDismissible: false, // prevent user interaction
      builder: (_) => WillPopScope(
        onWillPop: () async => false,
        child: Container(
          color: Colors.black.withOpacity(0.5),
          alignment: Alignment.center,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: const [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text(
                "Recapturing user image...",
                style: TextStyle(color: Colors.white, fontSize: 16),
              ),
            ],
          ),
        ),
      ),
    );

    try {
      final updatedUser = user.copyWith(
        faceEmbeddings: capturedEmbeddings[user.id]!,
        embedding: capturedEmbeddings[user.id]!.first,
      );
      await _userService.addUser(updatedUser);
      await FaceModelService.reload();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("✅ User embeddings updated!")),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("❌ Error updating embeddings: $e")),
      );
    } finally {
      Navigator.of(context, rootNavigator: true).pop(); // hide overlay
      _isRecapturing[user.id] = false;
      setState(() {});
    }
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
      await FaceModelService.reload();
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

/// Dialog wrapper for face capture
class FaceCaptureDialog extends StatefulWidget {
  final CameraService cameraService;
  final void Function(List<Uint8List> photos, List<List<double>> embeddings) onCompleted;

  const FaceCaptureDialog({
    super.key,
    required this.cameraService,
    required this.onCompleted,
  });

  @override
  State<FaceCaptureDialog> createState() => _FaceCaptureDialogState();
}

class _FaceCaptureDialogState extends State<FaceCaptureDialog> {
  List<Uint8List> _photos = [];
  List<List<double>> _embeddings = [];

  void _handleCompleted(List<Uint8List> photos, List<List<double>> embeddings) {
    // ✅ only cache in state
    setState(() {
      _photos = photos;
      _embeddings = embeddings;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDoneEnabled = _embeddings.length == 3;

    return AlertDialog(
      content: SizedBox(
        width: 400,
        height: 500,
        child: widget.cameraService.isInitialized
            ? FaceCaptureWidget(
          cameraService: widget.cameraService,
          onCompleted: _handleCompleted,
        )
            : const Center(child: CircularProgressIndicator()),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("Cancel"),
        ),
        TextButton(
          onPressed: _embeddings.length == 3
              ? () {
            // ✅ Commit update only here
            widget.onCompleted(_photos, _embeddings);
            Navigator.pop(context);
          }
              : null, // disabled until 3 photos
          child: const Text("Done"),
        ),
      ],
    );
  }
}
