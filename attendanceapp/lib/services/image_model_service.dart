import 'dart:typed_data';
import 'dart:convert';
import 'dart:developer' as developer;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:attendanceapp/configs_and_tools/debug.dart';

// Conditionally import dart:io (not available on web)
import 'dart:io' show Platform, ProcessInfo;

Debug debug = Debug(module: "image_model_service", enable: true);

class ImageModelService {
  final String tenantId;
  final DocumentReference<Map<String, dynamic>> _usersPhotoDoc;
  final DocumentReference<Map<String, dynamic>> _usersPhotoIndexDoc;

  static ImageModelService? _instance;

  static ImageModelService get instance {
    if (_instance == null) {
      throw Exception("ImageModelService not initialized. Call init() first.");
    }
    return _instance!;
  }

  static void init({required String tenantId}) {
    _instance = ImageModelService._internal(tenantId);
  }

  static void clear() => _instance = null;

  ImageModelService._internal(this.tenantId)
      : _usersPhotoDoc = FirebaseFirestore.instance
      .collection("${tenantId}_photos")
      .doc("usersPhoto"),
        _usersPhotoIndexDoc = FirebaseFirestore.instance
            .collection("${tenantId}_photos")
            .doc("usersPhotoIndex");

  Future<void> saveCapturedPhotos({
    required String employeeId,
    required List<Uint8List> photos,
  }) async {
    final labeled = _mapPhotosToLabels(photos);
    await _saveUserPhotos(employeeId: employeeId, photos: labeled);
  }

  Future<void> _saveUserPhotos({
    required String employeeId,
    required Map<String, Uint8List> photos,
  }) async {
    try {
      final Map<String, dynamic> employeePhotos = {};

      for (final entry in photos.entries) {
        final base64 = base64Encode(entry.value);
        final double sizeKB = utf8.encode(base64).length / 1024;
        employeePhotos[entry.key] = base64;
      }

      employeePhotos["timestamp"] = FieldValue.serverTimestamp();
      final String photoKey = "${employeeId}photos";

      await _usersPhotoDoc.set({
        photoKey: employeePhotos,
      }, SetOptions(merge: true));

      await _usersPhotoIndexDoc.set({
        employeeId: photoKey,
      }, SetOptions(merge: true));

    } catch (e) {
      debug.log("❌ Error saving photos for $employeeId: $e");
      rethrow;
    }
  }

  Future<Map<String, Uint8List>> getUserPhotos(String employeeId) async {
    try {
      final indexSnap = await _usersPhotoIndexDoc.get();
      if (!indexSnap.exists) {
        debug.log("⚠️ usersPhotoIndex document not found.");
        return {};
      }

      final indexData = indexSnap.data();
      final String? photoKey = indexData?[employeeId];
      if (photoKey == null) {
        debug.log("⚠️ No index entry for $employeeId");
        return {};
      }

      final photoSnap = await _usersPhotoDoc.get();
      if (!photoSnap.exists) {
        debug.log("⚠️ usersPhoto document not found.");
        return {};
      }

      final data = photoSnap.data();
      if (data == null || !data.containsKey(photoKey)) {
        debug.log("⚠️ No photo data for key $photoKey");
        return {};
      }

      final Map<String, dynamic> employeePhotos =
      (data[photoKey] as Map<String, dynamic>);
      final Map<String, Uint8List> decoded = {};

      employeePhotos.forEach((key, value) {
        if (key != "timestamp" && value is String) {
          decoded[key] = base64Decode(value);
        }
      });

      debug.log("📥 [$employeeId] Retrieved ${decoded.length} photos");
      return decoded;
    } catch (e) {
      debug.log("❌ Error retrieving photos for $employeeId: $e");
      return {};
    }
  }

  Map<String, Uint8List> _mapPhotosToLabels(List<Uint8List> photos) {
    const labels = ["front", "left", "right", "extra1", "extra2"];
    final Map<String, Uint8List> map = {};
    for (int i = 0; i < photos.length && i < labels.length; i++) {
      map[labels[i]] = photos[i];
    }
    return map;
  }

  Future<void> testConnection() async {
    try {
      await _usersPhotoDoc.set({
        "testConnection": FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      await _usersPhotoIndexDoc.set({
        "testConnection": FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      debug.log("✅ Firestore connection OK.");
    } catch (e) {
      debug.log("❌ Firestore connection failed: $e");
    }
  }

}
