import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';

class CameraService {
  static final CameraService _instance = CameraService._internal();
  factory CameraService() => _instance;
  CameraService._internal();

  CameraController? controller;
  Future<void>? initializeFuture;

  Future<void> initCamera() async {
    if (controller != null) return; // Already initialized

    List<CameraDescription> cameras = [];

    try {
      if (kIsWeb || defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS) {
        cameras = await availableCameras();
      }

      if (cameras.isNotEmpty) {
        final frontCamera = cameras.firstWhere(
              (c) => c.lensDirection == CameraLensDirection.front,
          orElse: () => cameras.first,
        );
        controller = CameraController(frontCamera, ResolutionPreset.medium);
        initializeFuture = controller!.initialize();
        await initializeFuture;
      }
    } catch (e) {
      debugPrint("Camera initialization error: $e");
    }
  }
}
