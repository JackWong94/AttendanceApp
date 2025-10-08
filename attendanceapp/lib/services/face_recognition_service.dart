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
    final descriptor = await webFaceApi.WebFaceApi.computeFaceDescriptorSafe(
      resized,
    );
    if (descriptor.isEmpty) return null;

    // ✅ Normalize the query embedding
    final normalizedQuery = _normalize(descriptor);

    // ✅ Normalize all stored embeddings before comparison
    final normalizedEmbeddings = FaceModelService.embeddings.map(
          (userId, embedding) => MapEntry(userId, _normalize(embedding)),
    );

    // Step 3: Compare with embeddings
    final userId = _findBestMatch(normalizedQuery, normalizedEmbeddings);
    if (userId == null) return null;

    // Step 4: Load full UserModel from UserModelService
    final user = await UserModelService.instance.getUserById(userId);
    return user;
  }

  /// Compare descriptor with all users, return best match userId if under threshold
  static String? _findBestMatch(
      List<double> query, Map<String, List<double>> embeddings) {
    String? bestUserId;
    double bestDistance = double.infinity;
    const threshold = 0.40; // adjust threshold as needed

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

  /// ✅ Normalize embedding to unit vector (for fair distance comparison)
  static List<double> _normalize(List<double> v) {
    final norm = sqrt(v.fold(0, (sum, x) => sum + x * x));
    if (norm == 0) return v;
    return v.map((x) => x / norm).toList();
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
