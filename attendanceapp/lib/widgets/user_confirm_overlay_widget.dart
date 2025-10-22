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
          // Semi-transparent dark background
          Positioned.fill(
            child: Container(
              color: Colors.black.withOpacity(0.4),
            ),
          ),

          // Center confirmation card
          Center(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 24),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 12,
                    offset: Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.face, size: 60, color: Colors.blue),
                  const SizedBox(height: 12),
                  Text(
                    "Detected: ${user.name}",
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    "Is this you?",
                    style: TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          minimumSize: const Size(120, 40),
                        ),
                        onPressed: () {
                          onConfirm();
                          remove();
                        },
                        icon: const Icon(Icons.check),
                        label: const Text("It's Me"),
                      ),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          minimumSize: const Size(120, 40),
                        ),
                        onPressed: () {
                          onReject();
                          remove();
                        },
                        icon: const Icon(Icons.close),
                        label: const Text("Not Me"),
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
