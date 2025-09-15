import 'dart:math';
import 'dart:typed_data';
import 'package:attendanceapp/services/web_face_api.dart' as webFaceApi;
import 'package:attendanceapp/services/face_model_service.dart';

class FaceRecognitionService {
  /// Capture photo -> compute embedding -> compare with cached embeddings
  static Future<String?> recognizeUser(Uint8List photoBytes) async {
    // Step 1: Convert bytes to image
    final img = await webFaceApi.uint8ListToImage(photoBytes);
    final resized = await webFaceApi.resizeImage(img, 160, 160);

    // Step 2: Compute face descriptor
    final descriptor = await webFaceApi.computeFaceDescriptorSafe(resized);
    if (descriptor.isEmpty) return null;

    // Step 3: Compare with embeddings
    return _findBestMatch(descriptor, FaceModelService.embeddings);
  }

  /// Compare descriptor with all users, return best match if under threshold
  static String? _findBestMatch(
      List<double> query, Map<String, List<double>> embeddings) {
    String? bestUser;
    double bestDistance = double.infinity;
    const threshold = 0.5; // 🔑 adjust if too strict/loose
    /*
    0.4 → very strict (only exact same face matches, risk: many false negatives).
    0.6 → more lenient (same person with glasses/angle/lighting still matches, risk: more false positives).
    Most projects use something between 0.45 – 0.6.
    */

    embeddings.forEach((user, embedding) {
      final dist = _euclideanDistance(query, embedding);
      if (dist < bestDistance) {
        bestDistance = dist;
        bestUser = user;
      }
    });

    print("Best match = $bestUser (distance: $bestDistance)");

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
