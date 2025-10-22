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
            child: GestureDetector(
              onTap: remove, // tap outside to close if desired
              child: Container(color: Colors.black.withOpacity(0.45)),
            ),
          ),

          // Center confirmation card
          Center(
            child: Container(
              width: MediaQuery.of(context).size.width * 0.8,
              constraints: const BoxConstraints(maxWidth: 340),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
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
                  // ✅ Gender-neutral icon
                  const Icon(Icons.account_circle_outlined,
                      size: 56, color: Colors.blueAccent),

                  const SizedBox(height: 16),

                  // ✅ User name (no underline, clean font)
                  Text(
                    "Detected: ${user.name}",
                    style: const TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                      decoration: TextDecoration.none, // 🚫 remove underline
                    ),
                    textAlign: TextAlign.center,
                  ),

                  const SizedBox(height: 10),

                  const Text(
                    "Is this you?",
                    style: TextStyle(
                      fontSize: 15,
                      color: Colors.black54,
                      decoration: TextDecoration.none, // 🚫 ensure no underline
                    ),
                  ),

                  const SizedBox(height: 24),

                  // ✅ Cleaner, rounded buttons
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      // 🔴 Not Me (Left)
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          minimumSize: const Size(110, 42),
                          elevation: 2,
                        ),
                        onPressed: () {
                          onReject();
                          remove();
                        },
                        icon: const Icon(Icons.close),
                        label: const Text("Not Me"),
                      ),

                      // 🟢 It's Me (Right)
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          minimumSize: const Size(110, 42),
                          elevation: 2,
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
