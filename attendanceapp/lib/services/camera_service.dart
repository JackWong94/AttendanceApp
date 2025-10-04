import 'dart:async';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class CameraService {
  // Singleton setup
  CameraService._privateConstructor();
  static final CameraService instance = CameraService._privateConstructor();

  CameraController? _controller;
  Future<void>? _initializeFuture;

  // Optional debug toggle
  static const bool _debug = true;

  /// Public getters
  CameraController? get controller => _controller;
  Future<void>? get initializeFuture => _initializeFuture;
  bool get isInitialized => _controller != null && _controller!.value.isInitialized;

  /// Initialize camera
  Future<void> initCamera({bool forceReinitOnWeb = false}) async {
    try {
      if (forceReinitOnWeb || _controller != null) {
        await disposeCamera();
      }

      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        if (_debug) debugPrint("⚠️ No cameras available");
        return;
      }

      final frontCamera = cameras.firstWhere(
            (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      _controller = CameraController(
        frontCamera,
        ResolutionPreset.medium,
        enableAudio: false,
      );

      if (kIsWeb) {
        // Web needs a short delay
        await Future.delayed(const Duration(milliseconds: 200));
      }

      _initializeFuture = _controller!.initialize();
      await _initializeFuture;

      if (_debug) debugPrint("✅ Camera initialized");
    } catch (e) {
      if (_debug) debugPrint("❌ Camera init error: $e");
      _controller = null;
      _initializeFuture = null;
    }
  }

  /// Dispose camera cleanly
  Future<void> disposeCamera() async {
    try {
      if (_controller != null) {
        await _controller!.dispose();
        if (_debug) debugPrint("🗑️ Camera disposed");
      }
    } catch (e) {
      if (_debug) debugPrint("❌ Error disposing camera: $e");
    } finally {
      _controller = null;
      _initializeFuture = null;
    }
  }
}
