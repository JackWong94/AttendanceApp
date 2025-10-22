import 'dart:typed_data';
import 'dart:convert';
import 'dart:developer' as developer;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:attendanceapp/configs_and_tools/debug.dart';
import 'package:attendanceapp/models/user_model.dart';
import 'package:uuid/uuid.dart';

// Conditionally import dart:io (ignored on web)
import 'dart:io' show Platform, ProcessInfo;

Debug debug = Debug(module: "image_model_service", enable: true);

class ImageModelService {
  final String tenantId;

  static ImageModelService? _instance;
  static const int _maxUserEntriesPerDoc = 800;
  static const int _maxAttendanceEntriesPerDoc = 800;

  final _uuid = const Uuid();
  final Map<String, Map<String, Uint8List>> _cache = {};

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

  ImageModelService._internal(this.tenantId);

  // ==========================================================================
  // 📸 USER PHOTO MANAGEMENT
  // ==========================================================================

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
        debug.log("📸 ${entry.key}: ${(sizeKB).toStringAsFixed(2)} KB");
        employeePhotos[entry.key] = base64;
      }
      employeePhotos["timestamp"] = FieldValue.serverTimestamp();

      // --- Determine where to store (based on index)
      final userIndexDoc = FirebaseFirestore.instance
          .collection("${tenantId}_photos")
          .doc("usersPhotoIndex");

      final indexSnap = await userIndexDoc.get();
      String targetDoc = "usersPhoto_1";
      int currentCount = 0;

      if (indexSnap.exists) {
        final data = indexSnap.data() ?? {};
        final lastDoc = data["lastDoc"] ?? targetDoc;
        targetDoc = lastDoc;
        currentCount = (data["counts"]?[lastDoc] ?? 0) as int;
      }

      if (currentCount >= _maxUserEntriesPerDoc) {
        final nextIndex = int.parse(targetDoc.split('_').last) + 1;
        targetDoc = "usersPhoto_$nextIndex";
        currentCount = 0;
      }

      final photoKey = "${employeeId}photos";
      final userPhotoDoc = FirebaseFirestore.instance
          .collection("${tenantId}_photos")
          .doc(targetDoc);

      await userPhotoDoc.set({
        photoKey: employeePhotos,
      }, SetOptions(merge: true));

      // --- Update index
      await userIndexDoc.set({
        "index": {photoKey: targetDoc},
        "counts": {targetDoc: currentCount + 1},
        "lastDoc": targetDoc,
      }, SetOptions(merge: true));

      debug.log("✅ Photos saved for $employeeId in $targetDoc (${photos.length} images)");
    } catch (e) {
      debug.log("❌ Error saving photos for $employeeId: $e");
      rethrow;
    }
  }

  Future<Map<String, Uint8List>> getUserPhotos(String employeeId) async {
    try {
      final photoKey = "${employeeId}photos";
      final userIndexDoc = FirebaseFirestore.instance
          .collection("${tenantId}_photos")
          .doc("usersPhotoIndex");

      final indexSnap = await userIndexDoc.get();
      if (!indexSnap.exists) {
        debug.log("⚠️ usersPhotoIndex not found.");
        return {};
      }

      final targetDocName = indexSnap.data()?["index"]?[photoKey];
      if (targetDocName == null) {
        debug.log("⚠️ No index entry for $photoKey");
        return {};
      }

      final targetDoc = await FirebaseFirestore.instance
          .collection("${tenantId}_photos")
          .doc(targetDocName)
          .get();

      if (!targetDoc.exists) {
        debug.log("⚠️ Target document $targetDocName not found.");
        return {};
      }

      final data = targetDoc.data();
      if (data == null || !data.containsKey(photoKey)) {
        debug.log("⚠️ No photo data found for $photoKey");
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

      debug.log("📥 [$employeeId] Retrieved ${decoded.length} photos from $targetDocName");
      return decoded;
    } catch (e) {
      debug.log("❌ Error retrieving photos for $employeeId: $e");
      return {};
    }
  }

  Future<void> deleteUserPhotos(String employeeId) async {
    try {
      final photoKey = "${employeeId}photos";
      final userIndexDoc = FirebaseFirestore.instance
          .collection("${tenantId}_photos")
          .doc("usersPhotoIndex");

      final indexSnap = await userIndexDoc.get();
      if (!indexSnap.exists) {
        debug.log("⚠️ usersPhotoIndex not found.");
        return;
      }

      final targetDocName = indexSnap.data()?["index"]?[photoKey];
      if (targetDocName == null) {
        debug.log("⚠️ No index entry found for $photoKey.");
        return;
      }

      final userPhotoDoc = FirebaseFirestore.instance
          .collection("${tenantId}_photos")
          .doc(targetDocName);

      await userPhotoDoc.update({photoKey: FieldValue.delete()});

      await userIndexDoc.set({
        "index": {photoKey: FieldValue.delete()},
      }, SetOptions(merge: true));

      _cache.remove(employeeId);
      debug.log("🗑️ Deleted user photos for $employeeId from $targetDocName");
    } catch (e) {
      debug.log("❌ Error deleting user photos for $employeeId: $e");
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

  Future<List<Uint8List>> getUserPhotoList(UserModel user) async {
    if (user.id.isEmpty) {
      debug.log("⚠️ UserModel has empty ID — cannot load photos.");
      return [];
    }

    final photosMap = await getUserPhotos(user.id);
    if (photosMap.isEmpty) return [];

    final order = ["front", "left", "right", "extra1", "extra2"];
    return [
      for (final label in order)
        if (photosMap.containsKey(label)) photosMap[label]!,
    ];
  }

  // ==========================================================================
  // 🧠 ATTENDANCE PHOTO MANAGEMENT
  // ==========================================================================

  Future<void> saveAttendancePhotoForUser({
    required UserModel user,
    required Uint8List imageBytes,
  }) async {
    try {
      final base64 = base64Encode(imageBytes);
      final uuid = _uuid.v4();
      final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-');
      final imageUrl = "attendance://${user.id}/$timestamp/$uuid";

      final attendanceIndexDoc = FirebaseFirestore.instance
          .collection("${tenantId}_photos")
          .doc("attendanceIndex");

      final attendanceIndexSnap = await attendanceIndexDoc.get();

      String targetDoc = "attendancePhoto_1";
      int currentCount = 0;

      if (attendanceIndexSnap.exists) {
        final data = attendanceIndexSnap.data() ?? {};
        final lastDoc = data["lastDoc"] ?? targetDoc;
        targetDoc = lastDoc;
        currentCount = (data["counts"]?[lastDoc] ?? 0) as int;
      }

      if (currentCount >= _maxAttendanceEntriesPerDoc) {
        final nextIndex = int.parse(targetDoc.split('_').last) + 1;
        targetDoc = "attendancePhoto_$nextIndex";
        currentCount = 0;
      }

      final attendancePhotoDoc = FirebaseFirestore.instance
          .collection("${tenantId}_photos")
          .doc(targetDoc);

      await attendancePhotoDoc.set({
        uuid: {
          "uuid": uuid,
          "userId": user.id,
          "name": user.name,
          "timestamp": FieldValue.serverTimestamp(),
          "base64": base64,
          "url": imageUrl,
        }
      }, SetOptions(merge: true));

      await attendanceIndexDoc.set({
        "index": {uuid: targetDoc},
        "counts": {targetDoc: currentCount + 1},
        "lastDoc": targetDoc,
      }, SetOptions(merge: true));

      debug.log("✅ Attendance photo saved for ${user.name} ($targetDoc)");
      debug.log("🔗 URL: $imageUrl");
    } catch (e) {
      debug.log("❌ Error saving attendance photo for ${user.name}: $e");
    }
  }

  Future<Map<String, dynamic>?> getAttendancePhotoByUuid(String uuid) async {
    try {
      final attendanceIndexDoc = FirebaseFirestore.instance
          .collection("${tenantId}_photos")
          .doc("attendanceIndex");

      final indexSnap = await attendanceIndexDoc.get();
      if (!indexSnap.exists) return null;

      final targetDocName = indexSnap.data()?["index"]?[uuid];
      if (targetDocName == null) return null;

      final targetDoc = await FirebaseFirestore.instance
          .collection("${tenantId}_photos")
          .doc(targetDocName)
          .get();

      return targetDoc.data()?[uuid];
    } catch (e) {
      debug.log("❌ Error retrieving attendance photo for uuid $uuid: $e");
      return null;
    }
  }

  Future<void> deleteAttendancePhoto(String uuid) async {
    try {
      final attendanceIndexDoc = FirebaseFirestore.instance
          .collection("${tenantId}_photos")
          .doc("attendanceIndex");

      final indexSnap = await attendanceIndexDoc.get();
      if (!indexSnap.exists) {
        debug.log("⚠️ attendanceIndex not found.");
        return;
      }

      final targetDocName = indexSnap.data()?["index"]?[uuid];
      if (targetDocName == null) {
        debug.log("⚠️ No index entry found for $uuid.");
        return;
      }

      final attendanceDoc = FirebaseFirestore.instance
          .collection("${tenantId}_photos")
          .doc(targetDocName);

      await attendanceDoc.update({uuid: FieldValue.delete()});

      await attendanceIndexDoc.set({
        "index": {uuid: FieldValue.delete()},
      }, SetOptions(merge: true));

      debug.log("🗑️ Deleted attendance photo with uuid $uuid from $targetDocName");
    } catch (e) {
      debug.log("❌ Error deleting attendance photo for $uuid: $e");
    }
  }

  // ==========================================================================
  // 🧩 CACHE + UTILITIES
  // ==========================================================================

  void clearCache() {
    _cache.clear();
    debug.log("🧹 ImageModelService cache cleared");
  }

  Future<Map<String, Uint8List>> loadUserPhotos(String employeeId) async {
    if (_cache.containsKey(employeeId)) {
      debug.log("⚡ Loaded $employeeId photos from cache");
      return _cache[employeeId]!;
    }

    final photos = await getUserPhotos(employeeId);
    if (photos.isNotEmpty) _cache[employeeId] = photos;
    return photos;
  }

  void traceMemory() {
    debug.log("🧩 Cache contains ${_cache.length} users");
    for (final entry in _cache.entries) {
      debug.log("   - ${entry.key}: ${entry.value.length} photos cached");
    }
  }

  Future<void> testConnection() async {
    try {
      final testDoc = FirebaseFirestore.instance
          .collection("${tenantId}_photos")
          .doc("testConnection");
      await testDoc.set({
        "ping": FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      debug.log("✅ Firestore connection OK.");
    } catch (e) {
      debug.log("❌ Firestore connection failed: $e");
    }
  }
}
