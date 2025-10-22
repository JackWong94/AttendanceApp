import 'dart:typed_data';
import 'dart:convert';
import 'dart:developer' as developer;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:attendanceapp/configs_and_tools/debug.dart';
import 'package:attendanceapp/models/user_model.dart';
import 'package:uuid/uuid.dart';

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

  // ---------------------------------------------------------------------------
  // 📸 USER PHOTO MANAGEMENT (existing)
  // ---------------------------------------------------------------------------

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
      final String photoKey = "${employeeId}photos";

      await _usersPhotoDoc.set({
        photoKey: employeePhotos,
      }, SetOptions(merge: true));

      await _usersPhotoIndexDoc.set({
        employeeId: photoKey,
      }, SetOptions(merge: true));

      debug.log("✅ Photos saved for $employeeId (${photos.length} images)");
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

  Future<Map<String, Uint8List>> getUserPhotosByModel(UserModel user) async {
    if (user.id.isEmpty) {
      debug.log("⚠️ UserModel has empty ID, cannot fetch photos.");
      return {};
    }
    return await getUserPhotos(user.id);
  }

  Future<List<Uint8List>> getUserPhotoList(UserModel user) async {
    final photosMap = await getUserPhotosByModel(user);
    final order = ["front", "left", "right", "extra1", "extra2"];
    return [
      for (var key in order)
        if (photosMap.containsKey(key)) photosMap[key]!,
    ];
  }

  Future<void> deleteUserPhotos({
    required String employeeId,
    String? label,
  }) async {
    try {
      final indexSnap = await _usersPhotoIndexDoc.get();
      if (!indexSnap.exists) return;

      final indexData = indexSnap.data();
      final String? photoKey = indexData?[employeeId];
      if (photoKey == null) return;

      final photoSnap = await _usersPhotoDoc.get();
      if (!photoSnap.exists) return;

      final data = photoSnap.data();
      if (data == null || !data.containsKey(photoKey)) return;

      final Map<String, dynamic> employeePhotos =
      Map<String, dynamic>.from(data[photoKey]);

      if (label != null) {
        employeePhotos.remove(label);
        debug.log("🗑️ Deleted '$label' photo for $employeeId");
      } else {
        data.remove(photoKey);
        await _usersPhotoDoc.set(data, SetOptions(merge: false));
        await _usersPhotoIndexDoc.update({employeeId: FieldValue.delete()});
        debug.log("🗑️ Deleted ALL photos for $employeeId");
        return;
      }

      await _usersPhotoDoc.set({
        photoKey: employeePhotos,
      }, SetOptions(merge: true));

      if (_cache.containsKey(employeeId)) {
        if (label != null) {
          _cache[employeeId]!.remove(label);
        } else {
          _cache.remove(employeeId);
        }
      }
      debug.log("✅ Delete operation complete for $employeeId");
    } catch (e) {
      debug.log("❌ Error deleting photos for $employeeId: $e");
    }
  }

  final Map<String, Map<String, Uint8List>> _cache = {};
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

  // ---------------------------------------------------------------------------
  // 🧠 ATTENDANCE PHOTO MANAGEMENT (scalable with index + rollover)
  // ---------------------------------------------------------------------------

  final _uuid = const Uuid();
  static const int _maxEntriesPerDoc = 800;

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

      if (currentCount >= _maxEntriesPerDoc) {
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
}
