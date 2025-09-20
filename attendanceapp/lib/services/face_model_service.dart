import 'dart:typed_data';
import 'dart:async';
import 'dart:html' as html;
import 'package:flutter/services.dart' show rootBundle;
import 'web_face_api.dart' as webFaceApi;
import 'user_model_service.dart';
import '../models/user_model.dart';

class FaceModelService {
  static bool _modelsLoaded = false;
  static bool _embeddingsLoaded = false;
  static bool _warmingUp = false;

  static final Map<String, List<double>> _userEmbeddings = {};
  static Map<String, List<double>> get embeddings => _userEmbeddings;

  static bool get isWarmingUp => _warmingUp;

  static Future<void> loadModels() async {
    if (_modelsLoaded) return;
    await webFaceApi.loadModels();
    _modelsLoaded = true;
    print("Face-api.js models loaded");
  }

  static Future<void> loadEmbeddings() async {
    if (_embeddingsLoaded) return;
    final users = await UserModelService.instance.getAllUsers();
    for (var user in users) {
      _userEmbeddings[user.id] = user.embedding;
    }
    _embeddingsLoaded = true;
    print("User embeddings loaded");
  }

  static Future<void> initialize() async {
    await loadModels();
    await loadEmbeddings();
  }

  static Future<void> warmUp() async {
    if (_warmingUp) return;
    _warmingUp = true;
    try {
      final dummyImage = await loadAssetImageElement('assets/warmup_face.png');
      await webFaceApi.computeFaceDescriptorSafe(dummyImage);
      print("Face model warm-up complete");
    } catch (e) {
      print("Face warm-up failed: $e");
    } finally {
      _warmingUp = false;
    }
  }

  static Future<void> reload() async {
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
