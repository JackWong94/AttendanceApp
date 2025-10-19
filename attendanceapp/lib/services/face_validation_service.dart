import 'dart:math' as math;
import 'package:attendanceapp/configs_and_tools/debug.dart';

Debug debug = Debug(module: "face_validation_service", enable: false);

class FaceValidationResult {
  final bool isValid;
  final String? message; // guidance for user
  FaceValidationResult({required this.isValid, this.message});
}

class FaceValidationService {
  static const double resizedSize = 160.0;
  static const double circleCenter = resizedSize / 2.0;
  static const double circleRadius = resizedSize / 2.0;

  /// Validate face position, size, and landmarks
  FaceValidationResult validateFace({
    required Map<String, dynamic> box,
    Map<String, dynamic>? landmarks,
    double centerThresholdRatio = 0.25,
    double tooFarRatio = 0.5,
    double tooCloseRatio = 0.68,
    int? step, // optional: 0 = straight, 1 = left, 2 = right
  }) {
    final double x = (box['x'] ?? 0).toDouble();
    final double y = (box['y'] ?? 0).toDouble();
    final double width = (box['width'] ?? 0).toDouble();
    final double height = (box['height'] ?? 0).toDouble();

    final double faceCenterX = x + width / 2.0;
    final double faceCenterY = y + height / 2.0;
    final double faceRadius = (width + height) / 4.0;

    debug.log('📦 Box: x=$x, y=$y, w=$width, h=$height');
    debug.log('🎯 Center: ($faceCenterX, $faceCenterY), radius=$faceRadius');

    // Center check
    final dx = faceCenterX - circleCenter;
    final dy = faceCenterY - circleCenter;
    final distanceFromCenter = math.sqrt(dx * dx + dy * dy);
    final centerThreshold = circleRadius * centerThresholdRatio;

    if (distanceFromCenter > centerThreshold) {
      debug.log('⚠️ Face not centered: dx=$dx, dy=$dy');
      return FaceValidationResult(
        isValid: false,
        message: "Center your face inside the circle.",
      );
    }

    // Distance/size check
    final tooFarThreshold = circleRadius * tooFarRatio;
    final tooCloseThreshold = circleRadius * tooCloseRatio;

    if (faceRadius < tooFarThreshold) {
      return FaceValidationResult(
        isValid: false,
        message: "Move closer to the camera.",
      );
    }

    if (faceRadius > tooCloseThreshold) {
      return FaceValidationResult(
        isValid: false,
        message: "Move slightly back.",
      );
    }

    // Landmarks check
    if (landmarks == null ||
        landmarks['nose'] == null ||
        landmarks['leftEye'] == null ||
        landmarks['rightEye'] == null) {
      return FaceValidationResult(
        isValid: false,
        message: "Face landmarks not detected. Try again.",
      );
    }

    // Step-based guidance
    if (step != null) {
      final nose = landmarks['nose'];
      final leftEye = landmarks['leftEye'];
      final rightEye = landmarks['rightEye'];
      final midX = (leftEye['x'] + rightEye['x']) / 2.0;
      final offset = (nose['x'] - midX);

      debug.log('👃 Nose offset: $offset');

      if (step == 0 && offset.abs() > 1.5) {
        return FaceValidationResult(
          isValid: false,
          message: "Face should look straight ahead.",
        );
      }
      if (step == 1 && offset > -3) {
        return FaceValidationResult(
          isValid: false,
          message: "Turn slightly more LEFT.",
        );
      }
      if (step == 2 && offset < 3) {
        return FaceValidationResult(
          isValid: false,
          message: "Turn slightly more RIGHT.",
        );
      }
    }

    return FaceValidationResult(isValid: true);
  }
}
