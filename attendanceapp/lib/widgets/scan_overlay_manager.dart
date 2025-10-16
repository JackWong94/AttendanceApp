import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/user_model.dart';

/// Manages showing and closing the scan success overlay.
class ScanOverlayManager {
  OverlayEntry? _overlayEntry;

  bool get isVisible => _overlayEntry != null;

  /// Show the overlay (Scan In / Scan Out confirmation)
  void show({
    required BuildContext context,
    required bool isScanIn,
    required UserModel user,
    required DateTime time,
    VoidCallback? onClosed,
  }) {
    remove(); // remove existing if any

    final formattedTime = DateFormat.Hm().format(time.toLocal());

    _overlayEntry = OverlayEntry(
      builder: (context) => Positioned.fill(
        child: GestureDetector(
          onTap: () {
            remove();
            onClosed?.call();
          },
          child: Material(
            color: Colors.black54,
            child: Center(
              child: FractionallySizedBox(
                widthFactor: 0.6,
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.black87,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        "Hello, ${user.name}",
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 20),
                      Text(
                        "${isScanIn ? 'Signed In' : 'Signed Out'} at $formattedTime",
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        "Tap anywhere or press back to close",
                        style: TextStyle(color: Colors.white70, fontSize: 16),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    Overlay.of(context).insert(_overlayEntry!);
  }

  /// Remove overlay if visible
  void remove() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }
}
