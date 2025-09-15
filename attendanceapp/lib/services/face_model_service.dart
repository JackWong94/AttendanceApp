import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'web_face_api.dart' as webFaceApi;

class FaceModelService {
  static bool _modelsLoaded = false;
  static bool _embeddingsLoaded = false;

  static final Map<String, List<double>> _userEmbeddings = {};

  static Map<String, List<double>> get embeddings => _userEmbeddings;

  // Load face-api.js models (only once)
  static Future<void> loadModels() async {
    if (_modelsLoaded) return;
    await webFaceApi.loadModels();
    _modelsLoaded = true;
    print("Face-api.js models loaded globally");
  }

  // Load all user embeddings from Firestore (only once)
  static Future<void> loadEmbeddings() async {
    if (_embeddingsLoaded) return;

    final snapshot = await FirebaseFirestore.instance.collection('users').get();
    for (var doc in snapshot.docs) {
      final data = doc.data();
      final name = data['name'] as String;
      final embeddingsJson = data['faceEmbeddings'] as List<dynamic>;
      final descriptor = (jsonDecode(embeddingsJson[0]) as List)
          .map((e) => e as double)
          .toList();
      _userEmbeddings[name] = descriptor;
    }

    _embeddingsLoaded = true;
    print("User embeddings loaded globally");
  }

  // Combined initializer
  static Future<void> initialize() async {
    await loadModels();
    await loadEmbeddings();
  }
}
