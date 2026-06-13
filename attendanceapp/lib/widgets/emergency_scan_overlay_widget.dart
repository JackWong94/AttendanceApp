import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:attendanceapp/models/user_model.dart';
import 'package:provider/provider.dart';
import 'package:attendanceapp/viewmodels/user_viewmodel.dart';

class EmergencyScanOverlayWidget {
  static OverlayEntry? _overlayEntry;

  static void show({
    required BuildContext context,
    required Uint8List imageBytes,
    required Function(UserModel user, bool isScanIn) onConfirm,
  }) {
    if (_overlayEntry != null) {
      _overlayEntry?.remove();
      _overlayEntry = null; // <-- cleanup here too
    }

    _overlayEntry = OverlayEntry(
      builder: (context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          backgroundColor: Colors.black54,
          body: _EmergencyScanOverlay(
            imageBytes: imageBytes,
            onConfirm: onConfirm,
            onClose: () {
              // ✅ 2️⃣ Also clean up when closed from inside widget
              _overlayEntry?.remove();
              _overlayEntry = null; // <-- cleanup here too
            },
          ),
        ),
      ),
    );

    Overlay.of(context).insert(_overlayEntry!);
  }
}

class _EmergencyScanOverlay extends StatefulWidget {
  final Uint8List imageBytes;
  final Function(UserModel user, bool isScanIn) onConfirm;
  final VoidCallback onClose;

  const _EmergencyScanOverlay({
    required this.imageBytes,
    required this.onConfirm,
    required this.onClose,
  });

  @override
  State<_EmergencyScanOverlay> createState() => _EmergencyScanOverlayState();
}

class _EmergencyScanOverlayState extends State<_EmergencyScanOverlay> {
  UserModel? _selectedUser;
  bool _isScanIn = true;

  @override
  Widget build(BuildContext context) {
    final users = context.watch<UserViewModel>().users;
    return Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: 400,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [
              BoxShadow(
                blurRadius: 10,
                color: Colors.black26,
                offset: Offset(0, 5),
              ),
            ],
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  "Emergency Attendance Scan",
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.red,
                  ),
                ),
                const SizedBox(height: 16),

                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.memory(
                    widget.imageBytes,
                    height: 200,
                    fit: BoxFit.cover,
                  ),
                ),

                const SizedBox(height: 16),


          DropdownButtonFormField<String>(
          isExpanded: true,
          value: _selectedUser?.id,
          hint: const Text("Select User"),
          onChanged: (userId) {
            final selected = users.firstWhere(
                  (u) => u.id == userId,
              orElse: () => users.first,
            );
            setState(() => _selectedUser = selected);
          },
          items: users.map((user) {
            return DropdownMenuItem(
              value: user.id,
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
                  style: TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 16),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey,
                      ),
                      onPressed: widget.onClose,
                      icon: const Icon(Icons.close),
                      label: const Text("Cancel"),
                    ),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                      ),
                      onPressed: _selectedUser == null
                          ? null
                          : () {
                        widget.onConfirm(_selectedUser!, _isScanIn);
                        widget.onClose();
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
