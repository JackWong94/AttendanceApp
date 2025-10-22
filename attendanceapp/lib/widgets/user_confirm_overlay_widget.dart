import 'package:flutter/material.dart';
import 'package:attendanceapp/models/user_model.dart';

class UserConfirmOverlayWidget {
  OverlayEntry? _overlayEntry;
  bool get isVisible => _overlayEntry != null;

  void show({
    required BuildContext context,
    required UserModel user,
    required VoidCallback onConfirm,
    required VoidCallback onReject,
  }) {
    if (_overlayEntry != null) return;

    _overlayEntry = OverlayEntry(
      builder: (context) => Stack(
        children: [
          // Dim background
          Positioned.fill(
            child: Container(color: Colors.black.withOpacity(0.4)),
          ),

          // Center confirmation card
          Center(
            child: Container(
              width: MediaQuery.of(context).size.width * 0.8, // ✅ smaller width
              constraints: const BoxConstraints(maxWidth: 360), // limit width
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 10,
                    offset: Offset(0, 5),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.face, size: 50, color: Colors.blueAccent),
                  const SizedBox(height: 12),
                  Text(
                    "Detected: ${user.name}",
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87, // ✅ softer dark text
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    "Is this you?",
                    style: TextStyle(
                      fontSize: 15,
                      color: Colors.black54, // ✅ more readable
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      // 🔴 Not Me on the LEFT
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          minimumSize: const Size(110, 40),
                        ),
                        onPressed: () {
                          onReject();
                          remove();
                        },
                        icon: const Icon(Icons.close),
                        label: const Text("Not Me"),
                      ),

                      // 🟢 It's Me on the RIGHT
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          minimumSize: const Size(110, 40),
                        ),
                        onPressed: () {
                          onConfirm();
                          remove();
                        },
                        icon: const Icon(Icons.check),
                        label: const Text("It's Me"),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );

    Overlay.of(context).insert(_overlayEntry!);
  }

  void remove() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }
}
