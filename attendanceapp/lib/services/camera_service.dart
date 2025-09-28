import 'dart:async';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class CameraService {
  CameraService._privateConstructor();
  static final CameraService instance = CameraService._privateConstructor();

  CameraController? controller;
  Future<void>? initializeFuture;

  bool get isInitialized => controller != null && controller!.value.isInitialized;

  Future<void> initCamera({bool forceReinitOnWeb = false}) async {
    try {
      if (forceReinitOnWeb || controller != null) {
        await disposeCamera();
      }

      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        debugPrint("⚠️ No cameras available");
        return;
      }

      final frontCamera = cameras.firstWhere(
            (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      controller = CameraController(
        frontCamera,
        ResolutionPreset.medium,
        enableAudio: false,
      );

      if (kIsWeb) {
        // Web needs a small delay
        await Future.delayed(const Duration(milliseconds: 200));
      }

      initializeFuture = controller!.initialize();
      await initializeFuture;

      debugPrint("✅ Camera initialized");
    } catch (e) {
      debugPrint("❌ Camera init error: $e");
      controller = null;
      initializeFuture = null;
    }
  }

  Future<void> disposeCamera() async {
    try {
      if (controller != null) {
        await controller!.dispose();
        debugPrint("🗑️ Camera disposed");
      }
    } catch (e) {
      debugPrint("❌ Error disposing camera: $e");
    } finally {
      controller = null;
      initializeFuture = null;
    }
  }
}
