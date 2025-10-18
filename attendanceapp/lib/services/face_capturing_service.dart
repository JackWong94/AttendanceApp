// lib/services/face_capturing_service.dart
import 'dart:typed_data';
import 'dart:math' as math;
import 'package:attendanceapp/services/camera_service.dart';
import 'package:attendanceapp/web_face_api.dart' as webFaceApi;
import 'package:attendanceapp/configs_and_tools/debug.dart';
import 'face_validation_service.dart';

Debug debug = Debug(module: "face_capturing_service", enable: true);

class FaceCaptureResult {
  final Uint8List photo;
  final List<double> embedding;
  FaceCaptureResult(this.photo, this.embedding);
}

class FaceCaptureService {
  static const double resizedSize = 160.0;
  static const double circleCenter = resizedSize / 2.0;
  static const double circleRadius = resizedSize / 2.0;

  final CameraService cameraService;

  FaceCaptureService(this.cameraService);

  /// Capture a face for the given step (0 = straight, 1 = left, 2 = right)
  Future<FaceCaptureResult?> captureFace(int step) async {
    if (!cameraService.isInitialized) {
      throw Exception("Camera not initialized.");
    }

    final controller = cameraService.controller!;
    final picture = await controller.takePicture();
    final bytes = await picture.readAsBytes();

    // Convert to image and resize for face detection
    final img = await webFaceApi.WebFaceApi.uint8ListToImage(bytes);
    final resizedImg = await webFaceApi.WebFaceApi.resizeImage(
      img,
      resizedSize.toInt(),
      resizedSize.toInt(),
    );

    final faceData = await webFaceApi.WebFaceApi.detectFaceWithBox(resizedImg);
    if (faceData == null || faceData['descriptor'] == null) {
      throw Exception("No face detected.");
    }

    // --- Validate face position, size, and step ---
    final validationService = FaceValidationService();
    final result = validationService.validateFace(
      box: faceData['box'],
      landmarks: faceData['landmarks'],
      step: step,
    );

    if (!result.isValid) {
      throw Exception(result.message);
    }

    // --- Extract descriptor ---
    final descriptor = List<double>.from(faceData['descriptor']);

    return FaceCaptureResult(bytes, descriptor);
  }
}
