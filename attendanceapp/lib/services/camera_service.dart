import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class CameraService {
  // Singleton
  static final CameraService _instance = CameraService._internal();
  factory CameraService() => _instance;
  CameraService._internal();

  CameraController? controller;
  Future<void>? initializeFuture;

  /// Initialize camera (mobile + web)
  /// `forceReinitOnWeb` = true to reinitialize on web
  Future<void> initCamera({bool forceReinitOnWeb = false}) async {
    // Skip if mobile and already initialized
    if (!kIsWeb && controller != null && controller!.value.isInitialized) return;

    // Dispose previous controller on web if needed
    if (kIsWeb && controller != null && forceReinitOnWeb) {
      try {
        await controller!.dispose();
        controller = null;
        initializeFuture = null;
      } catch (e) {
        debugPrint("Error disposing web camera: $e");
      }
    }

    try {
      // Get available cameras
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        debugPrint("No cameras found");
        return;
      }

      // Pick front camera if available
      final frontCamera = cameras.firstWhere(
            (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      // Create controller
      controller = CameraController(
        frontCamera,
        ResolutionPreset.medium,
        enableAudio: !kIsWeb, // disable audio on web
      );

      initializeFuture = controller!.initialize();
      await initializeFuture;
    } catch (e) {
      debugPrint("Camera initialization error: $e");
      controller = null;
      initializeFuture = null;
    }
  }

  /// Helper: is camera ready
  bool get isCameraAvailable => controller != null && controller!.value.isInitialized;

  /// Dispose camera manually if needed
  Future<void> disposeCamera() async {
    if (controller != null) {
      try {
        await controller!.dispose();
      } catch (e) {
        debugPrint("Error disposing camera: $e");
      } finally {
        controller = null;
        initializeFuture = null;
      }
    }
  }
}
