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

  /// Initialize or reinitialize camera
  /// [forceReinitOnWeb] ensures web camera is disposed and recreated
  Future<void> initCamera({bool forceReinitOnWeb = false}) async {
    try {
      // Dispose web camera if forced
      if (kIsWeb && controller != null && forceReinitOnWeb) {
        await controller!.dispose();
        controller = null;
        initializeFuture = null;
      }

      // Skip initialization if controller already exists on mobile
      if (!kIsWeb && controller != null) return;

      // Get available cameras
      final cameras = await availableCameras();
      if (cameras.isEmpty) return;

      // Select front camera or fallback to first
      final frontCamera = cameras.firstWhere(
            (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      // Create controller
      controller = CameraController(
        frontCamera,
        ResolutionPreset.medium,
        enableAudio: !kIsWeb, // disable audio for web
      );

      // Initialize
      initializeFuture = controller!.initialize();
      await initializeFuture;
    } catch (e) {
      debugPrint("Camera initialization error: $e");
      controller = null;
      initializeFuture = null;
    }
  }

  /// Dispose camera controller safely
  Future<void> disposeCamera() async {
    try {
      await controller?.dispose();
    } catch (e) {
      debugPrint("Error disposing camera: $e");
    } finally {
      controller = null;
      initializeFuture = null;
    }
  }

  /// Helper to check if camera is available and initialized
  bool get isCameraAvailable =>
      controller != null && controller!.value.isInitialized;
}
