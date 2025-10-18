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

  // Multi embeddings per user for hybrid recognition
  static final Map<String, List<List<double>>> _multiUserEmbeddings = {};
  static Map<String, List<List<double>>> get multiEmbeddings => _multiUserEmbeddings;

  // First embedding for backward compatibility / quick compare
  static final Map<String, List<double>> _userEmbeddings = {};
  static Map<String, List<double>> get embeddings => _userEmbeddings;

  static bool get isWarmingUp => _warmingUp;

  /// Load face-api.js models
  static Future<void> loadModels() async {
    if (_modelsLoaded) return;
    await webFaceApi.WebFaceApi.loadModels();
    _modelsLoaded = true;
    print("Face-api.js models loaded");
  }

  /// Load user embeddings from DB
  static Future<void> loadEmbeddings() async {
    if (_embeddingsLoaded) return;

    final users = await UserModelService.instance.getAllUsers();
    for (var user in users) {
      if (user.faceEmbeddings != null && user.faceEmbeddings!.isNotEmpty) {
        final allEmbeddings = <List<double>>[];

        // Since faceEmbeddings is already List<double>, just add each embedding
        for (final emb in user.faceEmbeddings!) {
          allEmbeddings.add(emb); // emb is already List<double>
        }

        _multiUserEmbeddings[user.id] = allEmbeddings;

        // Optionally store the first embedding in single embeddings map
        _userEmbeddings[user.id] = allEmbeddings[0];
      }
    }

    _embeddingsLoaded = true;
    print("User embeddings loaded: ${_multiUserEmbeddings.length} users");
  }

  /// Initialize models and embeddings
  static Future<void> initialize() async {
    await loadModels();
    await loadEmbeddings();
  }

  /// Warm-up face model using a dummy face image
  static Future<void> warmUp() async {
    if (_warmingUp) return;
    _warmingUp = true;
    try {
      final dummyImage = await loadAssetImageElementSafe('assets/warmup_face.png');
      if (dummyImage != null) {
        await webFaceApi.WebFaceApi.computeFaceDescriptorSafe(dummyImage);
      } else {
        print("⚠️ Warm-up skipped (asset missing)");
      }
      print("Face model warm-up complete");
    } catch (e) {
      print("Face warm-up failed: $e");
    } finally {
      _warmingUp = false;
    }
  }

  /// Reload models and embeddings
  static Future<void> reload() async {
    _modelsLoaded = false;
    _embeddingsLoaded = false;
    _userEmbeddings.clear();
    _multiUserEmbeddings.clear();
    await initialize();
  }

  /// Load an asset image as HTML ImageElement
  static Future<html.ImageElement?> loadAssetImageElementSafe(String path) async {
    try {
      final data = await rootBundle.load(path);
      final bytes = data.buffer.asUint8List();
      final blob = html.Blob([bytes]);
      final url = html.Url.createObjectUrlFromBlob(blob);
      final img = html.ImageElement(src: url);
      await img.onLoad.first;
      return img;
    } catch (e, st) {
      print("⚠️ Failed to load asset $path: $e");
      return null;
    }
  }
}
