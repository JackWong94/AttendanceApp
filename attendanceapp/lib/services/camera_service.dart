import 'dart:async';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:attendanceapp/configs_and_tools/debug.dart';

Debug debug = Debug(module: "camera_service", enable: true);
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

  CameraDescription? _cachedCamera;

  Future<void> initCamera({bool forceReinitOnWeb = false}) async {
    try {
      if (forceReinitOnWeb || _controller != null) {
        await disposeCamera();
      }

      // Only fetch cameras once
      final cameras = await availableCameras();

      // Cache the selected camera
      _cachedCamera ??= cameras.firstWhere(
            (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      _controller = CameraController(
        _cachedCamera!,
        ResolutionPreset.low, // faster init
        enableAudio: false,
      );

      if (kIsWeb) {
        int retries = 0;
        while (retries < 10) {
          debug.log("⏳  Waiting for camera stream... Try $retries");
          await Future.delayed(const Duration(milliseconds: 100));
          if (cameras.isNotEmpty) break; // ✅ camera stream ready
          retries++;
        }
      }

      _initializeFuture = _controller!.initialize();
      await _initializeFuture;

      if (_debug) debug.log("✅  Camera initialized quickly");
    } catch (e) {
      if (_debug) debug.log("❌ Camera init error: $e");
      _controller = null;
      _initializeFuture = null;
    }
  }


  /// Dispose camera cleanly
  Future<void> disposeCamera() async {
    try {
      if (_controller != null) {
        _controller!.dispose();
        if (_debug) debug.log("🗑️Camera disposed");
      }
    } catch (e) {
      if (_debug) debug.log("❌ Error disposing camera: $e");
    } finally {
      _controller = null;
      _initializeFuture = null;
    }
  }
}
