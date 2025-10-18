import 'dart:math';
import 'dart:typed_data';
import 'package:attendanceapp/web_face_api.dart' as webFaceApi;
import 'package:attendanceapp/services/face_model_service.dart';
import 'package:attendanceapp/services/user_model_service.dart';
import 'package:attendanceapp/models/user_model.dart';

class FaceRecognitionService {
  /// Capture photo -> compute embedding -> compare with cached embeddings
  /// Returns a UserModel if matched, otherwise null
  static Future<UserModel?> recognizeUser(Uint8List photoBytes) async {
    // Step 1: Convert bytes to image
    final img = await webFaceApi.WebFaceApi.uint8ListToImage(photoBytes);
    final resized = await webFaceApi.WebFaceApi.resizeImage(img, 160, 160);

    // Step 2: Compute face descriptor
    final descriptor = await webFaceApi.WebFaceApi.computeFaceDescriptorSafe(resized);
    if (descriptor.isEmpty) return null;

    // Step 3: Compare with embeddings
    final bestUserId = _findBestMatch(descriptor, FaceModelService.embeddings);
    if (bestUserId == null) return null;

    // Step 4: Load full UserModel from UserModelService
    final user = await UserModelService.instance.getUserById(bestUserId);
    return user;
  }

  /// Compare descriptor with all users and print their distances
  static String? _findBestMatch(List<double> query, Map<String, List<double>> embeddings) {
    String? bestUserId;
    double bestDistance = double.infinity;
    const threshold = 0.4; // adjust threshold as needed

    final results = <MapEntry<String, double>>[];

    embeddings.forEach((userId, embedding) {
      final dist = _euclideanDistance(query, embedding);
      results.add(MapEntry(userId, dist));

      if (dist < bestDistance) {
        bestDistance = dist;
        bestUserId = userId;
      }
    });

    // Sort by distance (best match first)
    results.sort((a, b) => a.value.compareTo(b.value));

    // Print all results clearly
    print("🔹 Total users compared: ${results.length}");
    for (final entry in results) {
      final userId = entry.key;
      final distance = entry.value.toStringAsFixed(4);
      print("→ $userId: distance = $distance");
    }

    print("🏆 Best match = $bestUserId (distance: ${bestDistance.toStringAsFixed(4)})");

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
