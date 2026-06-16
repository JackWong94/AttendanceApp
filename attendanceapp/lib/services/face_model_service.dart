import 'dart:typed_data';
import 'dart:async';
import 'dart:html' as html;
import 'package:flutter/services.dart' show rootBundle;
import '../web_face_api.dart' as webFaceApi;
import '../models/user_model.dart';

class FaceModelService {
  static bool _modelsLoaded = false;
  static bool _warmingUp = false;

  // Multi embeddings per user for hybrid recognition
  static final Map<String, List<List<double>>> _multiUserEmbeddings = {};

  static Map<String, List<List<double>>> get multiEmbeddings =>
      _multiUserEmbeddings;

  // First embedding for backward compatibility / quick compare
  static final Map<String, List<double>> _userEmbeddings = {};

  static Map<String, List<double>> get embeddings => _userEmbeddings;

  static bool get isWarmingUp => _warmingUp;

  static bool get hasEmbeddings => _userEmbeddings.isNotEmpty;

  /// Load face-api.js models once
  static Future<void> loadModels() async {
    if (_modelsLoaded) return;

    await webFaceApi.WebFaceApi.loadModels();

    _modelsLoaded = true;

    print("✅ Face-api.js models loaded");
  }

  /// Load embeddings from user list
  static Future<void> loadEmbeddingsFromUsers(
      List<UserModel> users,
      ) async {
    _multiUserEmbeddings.clear();
    _userEmbeddings.clear();

    for (final user in users) {
      if (user.faceEmbeddings.isEmpty) continue;

      _multiUserEmbeddings[user.id] = user.faceEmbeddings;

      _userEmbeddings[user.id] = user.faceEmbeddings.first;
    }

    print(
      "✅ User embeddings loaded: ${_userEmbeddings.length} users",
    );
  }

  /// Initialize model + embeddings
  static Future<void> initialize(
      List<UserModel> users,
      ) async {
    await loadModels();

    if (users.isNotEmpty) {
      await loadEmbeddingsFromUsers(users);
    } else {
      print("⚠️ FaceModelService initialized with empty user list");
    }
  }

  /// Force refresh embeddings when users change
  static Future<void> reload(
      List<UserModel> users,
      ) async {
    await loadModels();
  }

  /// Warm-up face model using a dummy face image
  static Future<void> warmUp() async {
    if (_warmingUp) return;

    _warmingUp = true;

    try {
      final dummyImage =
      await loadAssetImageElementSafe(
        'assets/warmup_face.png',
      );

      if (dummyImage != null) {
        await webFaceApi.WebFaceApi
            .computeFaceDescriptorSafe(dummyImage);
      } else {
        print("⚠️ Warm-up skipped (asset missing)");
      }

      print("✅ Face model warm-up complete");
    } catch (e) {
      print("❌ Face warm-up failed: $e");
    } finally {
      _warmingUp = false;
    }
  }

  /// Load asset image safely
  static Future<html.ImageElement?>
  loadAssetImageElementSafe(
      String path,
      ) async {
    try {
      final data = await rootBundle.load(path);

      final bytes =
      data.buffer.asUint8List();

      final blob = html.Blob([bytes]);

      final url =
      html.Url.createObjectUrlFromBlob(blob);

      final img =
      html.ImageElement(src: url);

      await img.onLoad.first;

      html.Url.revokeObjectUrl(url);

      return img;
    } catch (e) {
      print(
        "⚠️ Failed to load asset $path: $e",
      );
      return null;
    }
  }
}