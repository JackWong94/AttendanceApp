import 'dart:convert';
import 'package:attendanceapp/services/user_model_service.dart';
import 'web_face_api.dart' as webFaceApi;
import 'package:attendanceapp/models/user_model.dart';

class FaceModelService {
  static bool _modelsLoaded = false;
  static bool _embeddingsLoaded = false;

  // Map of docId -> embeddings
  static final Map<String, List<double>> _userEmbeddings = {};
  static Map<String, List<double>> get embeddings => _userEmbeddings;

  /// Load face-api.js models (only once)
  static Future<void> loadModels() async {
    if (_modelsLoaded) return;
    await webFaceApi.loadModels();
    _modelsLoaded = true;
    print("Face-api.js models loaded globally");
  }

  /// Load all user embeddings from UserModelService (only once)
  static Future<void> loadEmbeddings() async {
    if (_embeddingsLoaded) return;

    final userService = UserModelService();
    final users = await userService.getAllUsers(); // returns List<UserModel>

    for (var user in users) {
      // user.id is Firestore docId, user.embedding is List<double>
      _userEmbeddings[user.id] = user.embedding;
    }

    _embeddingsLoaded = true;
    print("User embeddings loaded globally via UserModelService");
  }

  /// Combined initializer
  static Future<void> initialize() async {
    print("Initializing FaceModelService");
    await loadModels();
    await loadEmbeddings();
  }

  /// Reload models and embeddings
  static Future<void> reload() async {
    print("Reloading FaceModelService");
    _modelsLoaded = false;
    _embeddingsLoaded = false;
    _userEmbeddings.clear();
    await initialize();
  }
}
