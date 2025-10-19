import 'dart:math';
import 'dart:typed_data';
import 'package:attendanceapp/web_face_api.dart' as webFaceApi;
import 'package:attendanceapp/services/face_model_service.dart';
import 'package:attendanceapp/services/user_model_service.dart';
import 'package:attendanceapp/models/user_model.dart';
import 'face_validation_service.dart';
import 'package:attendanceapp/configs_and_tools/debug.dart';

Debug debug = Debug(module: "face_recognition_service", enable: true);

class FaceRecognitionService {
  /// Capture photo -> detect face -> validate -> compute embedding -> match
  static Future<UserModel?> recognizeUser(Uint8List photoBytes) async {
    debug.log('📸 Starting face recognition...');

    // Convert to image and resize
    final img = await webFaceApi.WebFaceApi.uint8ListToImage(photoBytes);
    final resized = await webFaceApi.WebFaceApi.resizeImage(img, 160, 160);

    // Detect face
    final faceData = await webFaceApi.WebFaceApi.detectFaceWithBox(resized);
    if (faceData == null || faceData['descriptor'] == null) {
      debug.log('❌ No face detected');
      throw Exception("No face detected.");
    }
    debug.log('✅ Face detected');

    // Validate face position & orientation
    final validationService = FaceValidationService();
    final result = validationService.validateFace(
      box: faceData['box'],
      landmarks: faceData['landmarks'],
      step: 0, // straight ahead
    );
    if (!result.isValid) {
      debug.log('⚠️ Face validation failed: ${result.message}');
      throw Exception(result.message);
    }
    debug.log('✔️ Face validation passed');

    // Compute descriptor
    final descriptor = List<double>.from(faceData['descriptor']);
    debug.log('🧬 Descriptor length: ${descriptor.length}');

    if (descriptor.isEmpty) return null;

    // Match against cached embeddings
    final bestUserId =
    _findBestHybridMatch(descriptor, FaceModelService.multiEmbeddings);
    if (bestUserId == null) {
      debug.log('❌ No matching user found');
      return null;
    }

    debug.log('🏆 Best matched user ID: $bestUserId');
    return await UserModelService.instance.getUserById(bestUserId);
  }

  /// Hybrid matching using multiple embeddings per user
  static String? _findBestHybridMatch(
      List<double> query, Map<String, List<List<double>>> multiEmbeddings) {
    const threshold = 0.4;
    final results = <MapEntry<String, double>>[];

    // Compute min distance for each user
    multiEmbeddings.forEach((userId, embeddingsList) {
      double minDist = double.infinity;
      for (final emb in embeddingsList) {
        final dist = _euclideanDistance(query, emb);
        if (dist < minDist) minDist = dist;
      }
      results.add(MapEntry(userId, minDist));
    });

    // Sort by distance ascending (closest first)
    results.sort((a, b) => a.value.compareTo(b.value));

    // Log all user distances
    debug.log('🔹 All user distances (closest -> farthest):');
    for (final r in results) {
      debug.log('→ ${r.key}: distance = ${r.value.toStringAsFixed(4)}');
    }

    final closeUsers = results.where((r) => r.value < threshold).toList();
    if (closeUsers.isEmpty) {
      debug.log('❌ No users within threshold $threshold');
      return null;
    }

    if (closeUsers.length == 1) {
      debug.log('✔️ Single user within threshold: ${closeUsers.first.key}');
      return closeUsers.first.key;
    }

    // Refine among multiple close users
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

    debug.log('🏆 Best hybrid match = $bestUser (distance: ${bestDistance.toStringAsFixed(4)})');
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
