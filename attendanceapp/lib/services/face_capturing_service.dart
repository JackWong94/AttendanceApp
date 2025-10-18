// lib/services/face_capturing_service.dart
import 'dart:typed_data';
import 'dart:math' as math;
import 'package:attendanceapp/services/camera_service.dart';
import 'package:attendanceapp/web_face_api.dart' as webFaceApi;
import 'package:attendanceapp/configs_and_tools/debug.dart';

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
    if (!cameraService.isInitialized) throw Exception("Camera not initialized.");

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

    // --- Bounding box ---
    final box = faceData['box'];
    final double faceCenterX =
        (box['x'] ?? 0).toDouble() + (box['width'] ?? 0).toDouble() / 2.0;
    final double faceCenterY =
        (box['y'] ?? 0).toDouble() + (box['height'] ?? 0).toDouble() / 2.0;
    final double faceRadius =
        ((box['width'] ?? 0).toDouble() + (box['height'] ?? 0).toDouble()) / 4.0;

    // --- Check centeredness ---
    final double dx = faceCenterX - circleCenter;
    final double dy = faceCenterY - circleCenter;
    final double distanceFromCenter = math.sqrt(dx * dx + dy * dy);
    final double centerThreshold = circleRadius * 0.25;
    if (distanceFromCenter > centerThreshold) {
      throw Exception("Center your face inside the circle.");
    }

    // --- Check distance/size ---
    if (faceRadius < circleRadius * 0.5) {
      throw Exception("Move closer to the camera.");
    }
    if (faceRadius > circleRadius * 0.60) {
      throw Exception("Move slightly back.");
    }

    // --- Head direction (yaw) ---
    final landmarks = faceData['landmarks'];
    if (landmarks == null ||
        landmarks['nose'] == null ||
        landmarks['leftEye'] == null ||
        landmarks['rightEye'] == null) {
      throw Exception("Face landmarks not detected. Try again.");
    }

    final nose = landmarks['nose'];
    final leftEye = landmarks['leftEye'];
    final rightEye = landmarks['rightEye'];
    final midX = (leftEye['x'] + rightEye['x']) / 2.0;
    final offset = (nose['x'] - midX);

    // Check by step
    if (step == 0 && offset.abs() > 1.5) {
      throw Exception("Face should look straight ahead.");
    }
    if (step == 1 && offset > -3) {
      throw Exception("Turn slightly more LEFT.");
    }
    if (step == 2 && offset < 3) {
      throw Exception("Turn slightly more RIGHT.");
    }

    return FaceCaptureResult(bytes, List<double>.from(faceData['descriptor']));
  }
}
