import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:attendanceapp/models/user_model.dart';
import 'package:attendanceapp/services/user_model_service.dart';

class EmergencyScanOverlayWidget {
  static void show({
    required BuildContext context,
    required Uint8List imageBytes,
    required Function(UserModel user, bool isScanIn) onConfirm,
  }) {
    final overlay = OverlayEntry(
      builder: (context) => _EmergencyScanOverlay(
        imageBytes: imageBytes,
        onConfirm: onConfirm,
      ),
    );

    Overlay.of(context).insert(overlay);
  }
}

class _EmergencyScanOverlay extends StatefulWidget {
  final Uint8List imageBytes;
  final Function(UserModel user, bool isScanIn) onConfirm;

  const _EmergencyScanOverlay({
    required this.imageBytes,
    required this.onConfirm,
  });

  @override
  State<_EmergencyScanOverlay> createState() => _EmergencyScanOverlayState();
}

class _EmergencyScanOverlayState extends State<_EmergencyScanOverlay> {
  UserModel? _selectedUser;
  bool _isScanIn = true;
  List<UserModel> _users = [];

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    _users = await UserModelService.instance.getAllUsers();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black54,
      child: Center(
        child: Container(
          width: 400,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  "Emergency Attendance Scan",
                  style: TextStyle(
                      fontSize: 20, fontWeight: FontWeight.bold, color: Colors.red),
                ),
                const SizedBox(height: 16),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.memory(widget.imageBytes, height: 200, fit: BoxFit.cover),
                ),
                const SizedBox(height: 16),
                _users.isEmpty
                    ? const CircularProgressIndicator()
                    : DropdownButtonFormField<UserModel>(
                  value: _selectedUser,
                  hint: const Text("Select User"),
                  onChanged: (user) => setState(() => _selectedUser = user),
                  items: _users.map((user) {
                    return DropdownMenuItem(
                      value: user,
                      child: Text(user.name),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ChoiceChip(
                      label: const Text("Scan In"),
                      selected: _isScanIn,
                      onSelected: (_) => setState(() => _isScanIn = true),
                    ),
                    const SizedBox(width: 10),
                    ChoiceChip(
                      label: const Text("Scan Out"),
                      selected: !_isScanIn,
                      onSelected: (_) => setState(() => _isScanIn = false),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Text(
                  "⚠️ This photo will be sent to management for validation.",
                  style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.grey),
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close),
                      label: const Text("Cancel"),
                    ),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                      onPressed: _selectedUser == null
                          ? null
                          : () {
                        widget.onConfirm(_selectedUser!, _isScanIn);
                        Navigator.of(context).pop();
                      },
                      icon: const Icon(Icons.check),
                      label: const Text("Confirm"),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
