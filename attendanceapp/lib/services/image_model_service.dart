import 'dart:typed_data';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:attendanceapp/configs_and_tools/debug.dart';
import 'package:attendanceapp/models/user_model.dart';
import 'package:attendanceapp/services/image_collection_service.dart'; // ← new
import 'package:uuid/uuid.dart';

Debug debug = Debug(module: "image_model_service", enable: true);

class ImageModelService {
  final String tenantId;

  static ImageModelService? _instance;
  static const int _maxUserEntriesPerDoc = 800;
  static const int _maxAttendanceEntriesPerDoc = 800;

  final _uuid = const Uuid();
  final Map<String, Map<String, Uint8List>> _cache = {};

  late final ImageCollectionService _userCollection;
  late final ImageCollectionService _attendanceCollection;

  // ==========================================================================
  // 🔧 INIT / SINGLETON
  // ==========================================================================

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

  ImageModelService._internal(this.tenantId) {
    _userCollection = ImageCollectionService(
      tenantId: tenantId,
      baseCollection: "userPhotos",
      maxEntriesPerDoc: _maxUserEntriesPerDoc,
    );
    _attendanceCollection = ImageCollectionService(
      tenantId: tenantId,
      baseCollection: "attendancePhotos",
      maxEntriesPerDoc: _maxAttendanceEntriesPerDoc,
    );
  }

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
        employeePhotos[entry.key] = base64;
      }
      employeePhotos["timestamp"] = FieldValue.serverTimestamp();

      final photoKey = "${employeeId}photos";

      await _userCollection.saveEntry(
        indexName: "usersPhotoIndex",
        docPrefix: "usersPhoto",
        entryKey: photoKey,
        data: employeePhotos,
      );

      debug.log("✅ Photos saved for $employeeId (${photos.length} images)");
    } catch (e) {
      debug.log("❌ Error saving photos for $employeeId: $e");
      rethrow;
    }
  }

  Future<Map<String, Uint8List>> getUserPhotos(String employeeId) async {
    try {
      final photoKey = "${employeeId}photos";
      final data = await _userCollection.getEntry(
        indexName: "usersPhotoIndex",
        entryKey: photoKey,
      );
      if (data == null) return {};

      final Map<String, Uint8List> decoded = {};
      data.forEach((key, value) {
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

  Future<void> deleteUserPhotos(String employeeId) async {
    try {
      final photoKey = "${employeeId}photos";
      await _userCollection.deleteEntry(
        indexName: "usersPhotoIndex",
        entryKey: photoKey,
      );
      _cache.remove(employeeId);
      debug.log("🗑️ Deleted user photos for $employeeId");
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
      final uuid = _uuid.v4();
      final base64 = base64Encode(imageBytes);
      final timestamp = FieldValue.serverTimestamp();
      final data = {
        "uuid": uuid,
        "userId": user.id,
        "name": user.name,
        "timestamp": timestamp,
        "base64": base64,
        "url": "attendance://${user.id}/$uuid",
      };

      await _attendanceCollection.saveEntry(
        indexName: "attendanceIndex",
        docPrefix: "attendancePhoto",
        entryKey: uuid,
        data: data,
      );

      debug.log("✅ Attendance photo saved for ${user.name} ($uuid)");
    } catch (e) {
      debug.log("❌ Error saving attendance photo for ${user.name}: $e");
    }
  }

  Future<Map<String, dynamic>?> getAttendancePhotoByUuid(String uuid) async {
    try {
      return await _attendanceCollection.getEntry(
        indexName: "attendanceIndex",
        entryKey: uuid,
      );
    } catch (e) {
      debug.log("❌ Error retrieving attendance photo for uuid $uuid: $e");
      return null;
    }
  }

  Future<void> deleteAttendancePhoto(String uuid) async {
    try {
      await _attendanceCollection.deleteEntry(
        indexName: "attendanceIndex",
        entryKey: uuid,
      );
      debug.log("🗑️ Deleted attendance photo $uuid");
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
          .collection("${tenantId}_Photos")
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
