import 'dart:convert';
import 'package:attendanceapp/services/user_model_service.dart';
import 'web_face_api.dart' as webFaceApi;
import 'package:attendanceapp/models/user_model.dart';
import 'dart:html' as html;
import 'dart:async';       // For Completer
import 'dart:typed_data';  // For Uint8List
import 'dart:html' as html; // For ImageElement, Blob
import 'package:flutter/services.dart' show rootBundle;

class FaceModelService {
  static bool _modelsLoaded = false;
  static bool _embeddingsLoaded = false;
  static bool _warmingUp = false;

  // Map of docId -> embeddings
  static final Map<String, List<double>> _userEmbeddings = {};
  static Map<String, List<double>> get embeddings => _userEmbeddings;

  /// Whether the service is currently warming up
  static bool get isWarmingUp => _warmingUp;

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

  /// Warm up the face detection/recognition model by running a dummy inference
  static Future<void> warmUp() async {
    if (_warmingUp) return;
    _warmingUp = true;

    try {
      print("Warming up face models...");

      final dummyImage = await loadAssetImageElement('assets/warmup_face.png');
      await webFaceApi.computeFaceDescriptorSafe(dummyImage);

      print("Face model warm-up complete");
    } catch (e) {
      print("Face model warm-up failed: $e");
    } finally {
      _warmingUp = false;
    }
  }

  /// Reload models and embeddings
  static Future<void> reload() async {
    print("Reloading FaceModelService");
    _modelsLoaded = false;
    _embeddingsLoaded = false;
    _userEmbeddings.clear();
    await initialize();
  }

  static Future<html.ImageElement> loadAssetImageElement(String path) async {
    final ByteData data = await rootBundle.load(path);
    final Uint8List bytes = data.buffer.asUint8List();

    final blob = html.Blob([bytes]);
    final url = html.Url.createObjectUrlFromBlob(blob);
    final img = html.ImageElement(src: url);

    final completer = Completer<html.ImageElement>();
    img.onLoad.listen((_) => completer.complete(img));
    img.onError.listen((event) => completer.completeError('Failed to load image: $event'));

    return completer.future;
  }
}
