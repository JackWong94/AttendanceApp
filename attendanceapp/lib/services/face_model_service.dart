import 'dart:typed_data';
import 'dart:async';
import 'dart:html' as html;
import 'package:flutter/services.dart' show rootBundle;
import '../web_face_api.dart' as webFaceApi;
import 'user_model_service.dart';
import '../models/user_model.dart';

class FaceModelService {
  static bool _modelsLoaded = false;
  static bool _embeddingsLoaded = false;
  static bool _warmingUp = false;

  // User embeddings
  static final Map<String, List<double>> _userEmbeddings = {};
  static Map<String, List<double>> get embeddings => _userEmbeddings;

  static bool get isWarmingUp => _warmingUp;

  // Load face-api.js models
  static Future<void> loadModels() async {
    if (_modelsLoaded) return;
    await webFaceApi.WebFaceApi.loadModels();
    _modelsLoaded = true;
    print("Face-api.js models loaded");
  }

  // Load user embeddings from DB
  static Future<void> loadEmbeddings() async {
    if (_embeddingsLoaded) return;
    final users = await UserModelService.instance.getAllUsers();
    for (var user in users) {
      _userEmbeddings[user.id] = user.embedding;
    }
    _embeddingsLoaded = true;
    print("User embeddings loaded");
  }

  // Initialize both models and embeddings
  static Future<void> initialize() async {
    await loadModels();
    await loadEmbeddings();
  }

  // Warm-up face model using a dummy face image
  static Future<void> warmUp() async {
    if (_warmingUp) return;
    _warmingUp = true;
    try {
      final dummyImage = await loadAssetImageElement('assets/warmup_face.png');
      // Compute descriptor with caching to skip repeated steps next time
      await webFaceApi.WebFaceApi.computeFaceDescriptorSafe(
        dummyImage,
        cacheKey: "warmup_face",
      );
      print("Face model warm-up complete");
    } catch (e) {
      print("Face warm-up failed: $e");
    } finally {
      _warmingUp = false;
    }
  }

  // Reload models and embeddings
  static Future<void> reload() async {
    _modelsLoaded = false;
    _embeddingsLoaded = false;
    _userEmbeddings.clear();
    await initialize();
  }

  // Load an asset image as HTML ImageElement
  static Future<html.ImageElement> loadAssetImageElement(String path) async {
    final ByteData data = await rootBundle.load(path);
    final Uint8List bytes = data.buffer.asUint8List();
    final blob = html.Blob([bytes]);
    final url = html.Url.createObjectUrlFromBlob(blob);
    final img = html.ImageElement(src: url);

    final completer = Completer<html.ImageElement>();
    img.onLoad.listen((_) => completer.complete(img));
    img.onError.listen(
            (event) => completer.completeError('Failed to load image: $event'));
    return completer.future;
  }
}
