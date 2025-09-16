import 'dart:math';
import 'dart:typed_data';
import 'package:attendanceapp/services/web_face_api.dart' as webFaceApi;
import 'package:attendanceapp/services/face_model_service.dart';
import 'package:attendanceapp/services/user_model_service.dart';
import 'package:attendanceapp/models/user_model.dart';

class FaceRecognitionService {
  /// Capture photo -> compute embedding -> compare with cached embeddings
  /// Returns a UserModel if matched, otherwise null
  static Future<UserModel?> recognizeUser(Uint8List photoBytes) async {
    // Step 1: Convert bytes to image
    final img = await webFaceApi.uint8ListToImage(photoBytes);
    final resized = await webFaceApi.resizeImage(img, 160, 160);

    // Step 2: Compute face descriptor
    final descriptor = await webFaceApi.computeFaceDescriptorSafe(resized);
    if (descriptor.isEmpty) return null;

    // Step 3: Compare with embeddings
    final userId = _findBestMatch(descriptor, FaceModelService.embeddings);
    if (userId == null) return null;

    // Step 4: Load full UserModel from UserModelService
    final user = await UserModelService().getUserById(userId);
    return user;
  }

  /// Compare descriptor with all users, return best match userId if under threshold
  static String? _findBestMatch(
      List<double> query, Map<String, List<double>> embeddings) {
    String? bestUserId;
    double bestDistance = double.infinity;
    const threshold = 0.5; // adjust threshold as needed

    embeddings.forEach((userId, embedding) {
      final dist = _euclideanDistance(query, embedding);
      if (dist < bestDistance) {
        bestDistance = dist;
        bestUserId = userId;
      }
    });

    print("Best match = $bestUserId (distance: $bestDistance)");
    return bestDistance < threshold ? bestUserId : null;
  }

  static double _euclideanDistance(List<double> a, List<double> b) {
    double sum = 0;
    for (int i = 0; i < a.length; i++) {
      final diff = a[i] - b[i];
      sum += diff * diff;
    }
    return sqrt(sum);
  }
}
