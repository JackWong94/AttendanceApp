import 'dart:math';
import 'dart:typed_data';
import 'package:attendanceapp/web_face_api.dart' as webFaceApi;
import 'package:attendanceapp/services/face_model_service.dart';
import 'package:attendanceapp/services/user_model_service.dart';
import 'package:attendanceapp/models/user_model.dart';
import 'face_validation_service.dart'; // <-- import the validator

class FaceRecognitionService {
  /// Capture photo -> detect face -> validate -> compute embedding -> match
  static Future<UserModel?> recognizeUser(Uint8List photoBytes) async {
    // Convert to image and resize
    final img = await webFaceApi.WebFaceApi.uint8ListToImage(photoBytes);
    final resized = await webFaceApi.WebFaceApi.resizeImage(img, 160, 160);

    // Detect face
    final faceData = await webFaceApi.WebFaceApi.detectFaceWithBox(resized);
    if (faceData == null || faceData['descriptor'] == null) {
      throw Exception("No face detected.");
    }

    // Validate face position & orientation
    final validationService = FaceValidationService();
    final result = validationService.validateFace(
      box: faceData['box'],
      landmarks: faceData['landmarks'],
      step: 0, // straight ahead
    );
    if (!result.isValid) {
      throw Exception(result.message);
    }

    // Compute descriptor
    final descriptor = List<double>.from(faceData['descriptor']);
    if (descriptor.isEmpty) return null;

    // Match against cached embeddings
    final bestUserId =
    _findBestHybridMatch(descriptor, FaceModelService.multiEmbeddings);
    if (bestUserId == null) return null;

    return await UserModelService.instance.getUserById(bestUserId);
  }

  /// Hybrid matching using multiple embeddings per user
  static String? _findBestHybridMatch(
      List<double> query, Map<String, List<List<double>>> multiEmbeddings) {
    const threshold = 0.4;
    final results = <MapEntry<String, double>>[];

    multiEmbeddings.forEach((userId, embeddingsList) {
      double minDist = double.infinity;
      for (final emb in embeddingsList) {
        final dist = _euclideanDistance(query, emb);
        if (dist < minDist) minDist = dist;
      }
      results.add(MapEntry(userId, minDist));
    });

    results.sort((a, b) => a.value.compareTo(b.value));

    final closeUsers = results.where((r) => r.value < threshold).toList();
    if (closeUsers.length <= 1) return closeUsers.isNotEmpty ? closeUsers.first.key : null;

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
