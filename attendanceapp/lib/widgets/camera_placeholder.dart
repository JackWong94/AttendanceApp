import 'package:flutter/material.dart';

class CameraPlaceholder extends StatelessWidget {
  final String message;

  const CameraPlaceholder({
    super.key,
    this.message = "Camera not supported on this platform",
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 50.0),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              'assets/camera_placeholder.png',
              width: 200,
            ),
            const SizedBox(height: 16),
            Text(
              message,
              style: const TextStyle(fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }
}
