import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class CameraService {
  // Singleton
  static final CameraService instance = CameraService._internal();
  CameraService._internal();

  CameraController? controller;
  Future<void>? initializeFuture;

  /// Initialize or reinitialize camera
  Future<void> initCamera({bool forceReinitOnWeb = false}) async {
    try {
      // Always dispose if forced
      if (forceReinitOnWeb && controller != null) {
        await disposeCamera();
      }

      // Get available cameras
      final cameras = await availableCameras();
      if (cameras.isEmpty) return;

      // Select front camera or fallback to first
      final frontCamera = cameras.firstWhere(
            (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      controller = CameraController(
        frontCamera,
        ResolutionPreset.medium,
        enableAudio: false, // disable audio for web
      );

      initializeFuture = controller!.initialize();
      await initializeFuture;
    } catch (e) {
      debugPrint("Camera initialization error: $e");
      controller = null;
      initializeFuture = null;
    }
  }

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

  bool get isInitialized =>
      controller != null && controller!.value.isInitialized;
}
