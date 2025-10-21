import 'dart:typed_data';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:attendanceapp/configs_and_tools/debug.dart';

Debug debug = Debug(module: "image_model_service", enable: true);

class ImageModelService {
  final String tenantId;
  final DocumentReference<Map<String, dynamic>> _usersPhotoDoc;

  static ImageModelService? _instance;

  /// Singleton getter
  static ImageModelService get instance {
    if (_instance == null) {
      throw Exception("ImageModelService not initialized. Call init() first.");
    }
    return _instance!;
  }

  /// Initialize singleton
  static void init({required String tenantId}) {
    _instance = ImageModelService._internal(tenantId);
  }

  /// Clear instance
  static void clear() => _instance = null;

  /// Internal constructor
  ImageModelService._internal(this.tenantId)
      : _usersPhotoDoc = FirebaseFirestore.instance
      .collection("${tenantId}_photos")
      .doc("usersPhoto");

  /// 🔹 Public API — Accept List<Uint8List> like before
  Future<void> saveCapturedPhotos({
    required String employeeId,
    required List<Uint8List> photos,
  }) async {
    final labeled = _mapPhotosToLabels(photos);
    await _saveUserPhotos(employeeId: employeeId, photos: labeled);
  }

  /// 🔹 Internal saver — saves photos inside usersPhoto doc
  Future<void> _saveUserPhotos({
    required String employeeId,
    required Map<String, Uint8List> photos,
  }) async {
    try {
      final Map<String, dynamic> employeePhotos = {};
      double totalKB = 0;

      for (final entry in photos.entries) {
        final key = entry.key;
        final base64 = base64Encode(entry.value);
        final double sizeKB = utf8.encode(base64).length / 1024;
        totalKB += sizeKB;

        employeePhotos[key] = base64;
        debug.log("📸 [$employeeId] $key photo: ${sizeKB.toStringAsFixed(1)} KB");
      }

      employeePhotos["timestamp"] = FieldValue.serverTimestamp();

      // Update field like EMP001photos: {...}
      await _usersPhotoDoc.set({
        "${employeeId}photos": employeePhotos,
      }, SetOptions(merge: true));

      debug.log("💾 [$employeeId] Total memory: ${totalKB.toStringAsFixed(1)} KB saved successfully!");
    } catch (e) {
      debug.log("❌ Error saving photos for $employeeId: $e");
      rethrow;
    }
  }

  /// 🧩 Helper: map list to labeled fields (front, left, right, etc.)
  Map<String, Uint8List> _mapPhotosToLabels(List<Uint8List> photos) {
    const labels = ["front", "left", "right", "extra1", "extra2"];
    final Map<String, Uint8List> map = {};
    for (int i = 0; i < photos.length && i < labels.length; i++) {
      map[labels[i]] = photos[i];
    }
    return map;
  }

  /// 🔍 Retrieve specific employee photos back
  Future<Map<String, Uint8List>> getUserPhotos(String employeeId) async {
    try {
      final docSnap = await _usersPhotoDoc.get();
      if (!docSnap.exists) {
        debug.log("⚠️ usersPhoto document not found.");
        return {};
      }

      final data = docSnap.data();
      if (data == null || !data.containsKey("${employeeId}photos")) {
        debug.log("⚠️ No photo entry for $employeeId");
        return {};
      }

      final Map<String, dynamic> employeePhotos =
      (data["${employeeId}photos"] as Map<String, dynamic>);
      final Map<String, Uint8List> decoded = {};

      employeePhotos.forEach((key, value) {
        if (key != "timestamp" && value is String) {
          decoded[key] = base64Decode(value);
        }
      });

      debug.log("📥 [$employeeId] Retrieved ${decoded.length} photos");
      return decoded;
    } catch (e) {
      debug.log("❌ Error reading photos for $employeeId: $e");
      return {};
    }
  }

  /// 🧠 Firestore connectivity test
  Future<void> testConnection() async {
    try {
      await _usersPhotoDoc.set({"testConnection": FieldValue.serverTimestamp()},
          SetOptions(merge: true));
      debug.log("✅ Firestore connection OK.");
    } catch (e) {
      debug.log("❌ Firestore connection failed: $e");
    }
  }
}
