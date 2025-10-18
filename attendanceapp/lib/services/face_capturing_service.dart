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

    // --- Bounding box ---
    final box = faceData['box'];
    final double x = (box['x'] ?? 0).toDouble();
    final double y = (box['y'] ?? 0).toDouble();
    final double width = (box['width'] ?? 0).toDouble();
    final double height = (box['height'] ?? 0).toDouble();

    final double faceCenterX = x + width / 2.0;
    final double faceCenterY = y + height / 2.0;
    final double faceRadius = (width + height) / 4.0;

    debug.log('📦 Box: x=$x, y=$y, w=$width, h=$height');
    debug.log('🎯 Center: (${faceCenterX.toStringAsFixed(1)}, ${faceCenterY.toStringAsFixed(1)}) '
        'radius=${faceRadius.toStringAsFixed(1)}');

    // --- Check centeredness ---
    final double dx = faceCenterX - circleCenter;
    final double dy = faceCenterY - circleCenter;
    final double distanceFromCenter = math.sqrt(dx * dx + dy * dy);
    final double centerThreshold = circleRadius * 0.25;

    debug.log('🌀 Distance from center: ${distanceFromCenter.toStringAsFixed(2)} '
        '(threshold=${centerThreshold.toStringAsFixed(2)})');

    if (distanceFromCenter > centerThreshold) {
      debug.log('⚠️ Face not centered: dx=${dx.toStringAsFixed(2)}, dy=${dy.toStringAsFixed(2)}');
      throw Exception("Center your face inside the circle.");
    }

    // --- Check distance/size ---
    final double tooFarThreshold = circleRadius * 0.5;
    final double tooCloseThreshold = circleRadius * 0.60;

    if (faceRadius < tooFarThreshold) {
      debug.log('📏 Face too small (too far): radius=${faceRadius.toStringAsFixed(2)}, '
          'expected > ${tooFarThreshold.toStringAsFixed(2)}');
      throw Exception("Move closer to the camera.");
    }
    if (faceRadius > tooCloseThreshold) {
      debug.log('📏 Face too large (too close): radius=${faceRadius.toStringAsFixed(2)}, '
          'expected < ${tooCloseThreshold.toStringAsFixed(2)}');
      throw Exception("Move slightly back.");
    }

    // --- Landmarks and yaw ---
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

    // approximate yaw angle in degrees (for debug only)
    final yawAngle = offset * 10; // scaling factor for rough visualization
    debug.log('👃 Nose: $nose');
    debug.log('👁️ LeftEye: $leftEye, RightEye: $rightEye');
    debug.log('🎯 Yaw offset: ${offset.toStringAsFixed(2)}, '
        'angle≈${yawAngle.toStringAsFixed(1)}°');

    // --- Check by step ---
    if (step == 0 && offset.abs() > 1.5) {
      debug.log('⚠️ Step 0: Face should look straight ahead (offset=${offset.toStringAsFixed(2)})');
      throw Exception("Face should look straight ahead.");
    }
    if (step == 1 && offset > -3) {
      debug.log('⚠️ Step 1: Not turned left enough (offset=${offset.toStringAsFixed(2)})');
      throw Exception("Turn slightly more LEFT.");
    }
    if (step == 2 && offset < 3) {
      debug.log('⚠️ Step 2: Not turned right enough (offset=${offset.toStringAsFixed(2)})');
      throw Exception("Turn slightly more RIGHT.");
    }

    // --- Descriptor / embedding info ---
    final descriptor = List<double>.from(faceData['descriptor']);
    final score = math.sqrt(descriptor.fold(0.0, (sum, e) => sum + e * e));

    debug.log('✅ Face detected, score: ${score.toStringAsFixed(3)}');
    debug.log('🧬 Descriptor length: ${descriptor.length}');
    debug.log('🧬 Descriptor sample: [${descriptor.take(5).map((e) => e.toStringAsFixed(3)).join(", ")}...]');

    return FaceCaptureResult(bytes, descriptor);
  }
}
