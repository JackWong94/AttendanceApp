import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class CameraService {
  static final CameraService _instance = CameraService._internal();
  factory CameraService() => _instance;
  CameraService._internal();

  CameraController? controller;
  Future<void>? initializeFuture;

  /// Initialize or reinitialize camera
  Future<void> initCamera({bool forceReinitOnWeb = false}) async {
    // If mobile and already initialized, skip
    if (!kIsWeb && controller != null) return;

    // If web and forceReinitOnWeb, dispose previous controller
    if (kIsWeb && controller != null && forceReinitOnWeb) {
      try {
        await controller!.dispose();
        controller = null;
        initializeFuture = null;
      } catch (e) {
        debugPrint("Error disposing web camera: $e");
      }
    }

    List<CameraDescription> cameras = [];

    try {
      if (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS) {
        cameras = await availableCameras();
      }

      if (kIsWeb) {
        final cameras = await availableCameras();
        if (cameras.isNotEmpty) {
          final frontCamera = cameras.firstWhere(
                (c) => c.lensDirection == CameraLensDirection.front,
            orElse: () => cameras.first,
          );

          // Only request video (no audio)
          controller = CameraController(
            frontCamera,
            ResolutionPreset.medium,
            enableAudio: false, // 🔑 disable audio
          );

          initializeFuture = controller!.initialize();
          await initializeFuture;
        }
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

  /// Helper to check if camera is available
  bool get isCameraAvailable => controller != null && controller!.value.isInitialized;
}
