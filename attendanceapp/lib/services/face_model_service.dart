import 'dart:html' as html;
import 'package:flutter/services.dart' show rootBundle;
import 'package:attendanceapp/web_face_api.dart' as webFaceApi;
import 'package:attendanceapp/models/user_model.dart';
import 'package:attendanceapp/configs_and_tools/debug.dart';

Debug debug = Debug(module: "face_model_service", enable: true);
class FaceModelService {
  FaceModelService._(); //This is a private constructor to prevent instantiation of this class. Because all functions are static, no point of creating new instance
  static bool _modelsLoaded = false;
  static bool _warmingUp = false;

  // Multi embeddings per user for hybrid recognition
  static final Map<String, List<List<double>>> _multiUserEmbeddings = {};
  static Map<String, List<List<double>>> get multiEmbeddings =>
      _multiUserEmbeddings;

  static bool get isWarmingUp => _warmingUp;

  /// Load face-api.js models once
  static Future<void> loadModels() async {
    if (_modelsLoaded) return;
    await webFaceApi.WebFaceApi.loadModels();
    _modelsLoaded = true;
    debug.log("✅ Face-api.js models loaded");
  }

  /// Load embeddings from user list
  static Future<void> updateEmbeddings(
      List<UserModel> users,
      ) async {
    _multiUserEmbeddings.clear();

    for (final user in users) {
      if (user.faceEmbeddings.isEmpty) continue;
      _multiUserEmbeddings[user.id] = user.faceEmbeddings;
    }
    debug.log(
      "✅ User embeddings loaded: ${_multiUserEmbeddings.length} users",
    );
  }

  /// Initialize model + embeddings
  static Future<void> initialize() async {
    await loadModels();
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
        debug.log("⚠️ Warm-up skipped (asset missing)");
      }
      debug.log("✅ Face model warm-up complete");
    } catch (e) {
      debug.log("❌ Face warm-up failed: $e");
    } finally {
      _warmingUp = false;
    }
  }

  /// Load asset image safely
  static Future<html.ImageElement?> loadAssetImageElementSafe (String path) async {
    try {
      final data = await rootBundle.load(path);
      final bytes = data.buffer.asUint8List();
      final blob = html.Blob([bytes]);
      final url = html.Url.createObjectUrlFromBlob(blob);
      final img = html.ImageElement(src: url);
      await img.onLoad.first;
      html.Url.revokeObjectUrl(url);
      return img;
    } catch (e) {
      debug.log("⚠️ Failed to load asset $path: $e");
      return null;
    }
  }
}