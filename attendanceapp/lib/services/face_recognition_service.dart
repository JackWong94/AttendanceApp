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
    final img = await webFaceApi.WebFaceApi.uint8ListToImage(photoBytes);
    final resized = await webFaceApi.WebFaceApi.resizeImage(img, 160, 160);

    final descriptor = await webFaceApi.WebFaceApi.computeFaceDescriptorSafe(resized);
    if (descriptor.isEmpty) return null;

    final bestUserId = _findBestHybridMatch(descriptor, FaceModelService.multiEmbeddings);
    if (bestUserId == null) return null;

    return await UserModelService.instance.getUserById(bestUserId);
  }

  /// Hybrid matching using multiple embeddings per user
  static String? _findBestHybridMatch(
      List<double> query, Map<String, List<List<double>>> multiEmbeddings) {
    const threshold = 0.4;

    final results = <MapEntry<String, double>>[];

    multiEmbeddings.forEach((userId, embeddingsList) {
      // Compute the closest distance for this user among all their embeddings
      double minDist = double.infinity;
      for (final emb in embeddingsList) {
        final dist = _euclideanDistance(query, emb);
        if (dist < minDist) minDist = dist;
      }
      results.add(MapEntry(userId, minDist));
    });

    // Sort users by distance
    results.sort((a, b) => a.value.compareTo(b.value));

    // Print all users and their best distances
    print("🔹 All user distances:");
    for (final r in results) {
      print("→ ${r.key}: distance = ${r.value.toStringAsFixed(4)}");
    }

    // Hybrid refinement: if multiple users are very close (within threshold)
    final closeUsers = results.where((r) => r.value < threshold).toList();
    if (closeUsers.length <= 1) return closeUsers.isNotEmpty ? closeUsers.first.key : null;

    // If multiple close, compare all their embeddings to refine
    String? bestUser;
    double bestDistance = double.infinity;

    for (final r in closeUsers) {
      final embeddingsList = multiEmbeddings[r.key]!;
      for (final emb in embeddingsList) {
        final dist = _euclideanDistance(query, emb);
        if (dist < bestDistance) {
          bestDistance = dist;
          bestUser = r.key;
        }
      }
    }

    print("🏆 Best hybrid match = $bestUser (distance: ${bestDistance.toStringAsFixed(4)})");
    return bestDistance < threshold ? bestUser : null;
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
