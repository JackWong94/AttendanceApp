import 'package:flutter/material.dart';
import 'package:attendanceapp/models/user_model.dart';
import 'package:attendanceapp/services/user_model_service.dart';
import 'package:attendanceapp/services/face_model_service.dart';

class ManageUserPage extends StatefulWidget {
  const ManageUserPage({super.key});

  @override
  State<ManageUserPage> createState() => _ManageUserPageState();
}

class _ManageUserPageState extends State<ManageUserPage> {
  final UserModelService _userService = UserModelService.instance;
  List<UserModel> _users = [];
  bool _isLoading = true;

  // Track which users are being edited
  final Map<String, bool> _isEditing = {};

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    setState(() => _isLoading = true);
    _users = await _userService.getAllUsers();
    _isEditing.clear();
    for (var u in _users) _isEditing[u.id] = false;
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

  Future<void> _updateUserEmbedding(UserModel user) async {
    // Open dialog to input new embedding
    final controller = TextEditingController(
      text: user.embedding.join(','),
    );

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Update Embedding"),
        content: TextField(
          controller: controller,
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: "Enter embedding as comma-separated numbers",
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel")),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text("Update")),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final newEmbedding = controller.text
          .split(',')
          .map((e) => double.parse(e.trim()))
          .toList();

      final updatedUser = user.copyWith(
        embedding: newEmbedding,
        faceEmbeddings: [newEmbedding],
      );

      await _userService.addUser(updatedUser);
      FaceModelService.embeddings[user.id] = newEmbedding;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Embedding updated successfully")),
      );
      await _loadUsers();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to update embedding: $e")),
      );
    }
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
          final isEditing = _isEditing[user.id] ?? false;
          final nameController = TextEditingController(text: user.name);

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
                    child: TextField(
                      controller: nameController,
                      readOnly: !isEditing,
                      decoration: const InputDecoration(labelText: "Name"),
                    ),
                  ),
                  IconButton(
                    icon: Icon(isEditing ? Icons.save : Icons.edit, color: Colors.blue),
                    onPressed: () {
                      if (isEditing) _updateUserName(user, nameController.text);
                      _toggleEdit(user.id);
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.update, color: Colors.orange),
                    onPressed: () => _updateUserEmbedding(user),
                    tooltip: "Update Embedding",
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
