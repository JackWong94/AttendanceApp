import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';

class ImageModelService {
  static ImageModelService? _instance;
  final String tenantId;
  final CollectionReference<Map<String, dynamic>> _imagesRef;

  ImageModelService._internal(this.tenantId)
      : _imagesRef =
  FirebaseFirestore.instance.collection('${tenantId}_Images');

  // ✅ Initialize singleton (explicit re-init)
  static void init({required String tenantId}) {
    _instance = ImageModelService._internal(tenantId);
  }

  // ✅ Clear instance on logout
  static void clear() {
    _instance = null;
  }

  // ✅ Getter for instance
  static ImageModelService get instance {
    if (_instance == null) {
      throw Exception("ImageModelService not initialized yet!");
    }
    return _instance!;
  }

  /// Add or append image to Firestore (auto split if nearing 80% of 1MB)
  Future<void> saveCapturedPhotos({
    required String employeeId,
    required List<Uint8List> photos,
  }) async {
    const int maxDocSize = 1 * 1024 * 1024; // 1 MB limit
    const double threshold = 0.8;
    final int safeLimit = (maxDocSize * threshold).floor();

    final collection = _imagesRef.doc("users_photos").collection(employeeId);
    final snapshot = await collection.get();

    DocumentReference<Map<String, dynamic>>? targetDoc;
    Map<String, dynamic>? targetData;
    int totalBytes = 0;

    // 🔍 Step 1: Find existing doc that isn’t full
    for (final doc in snapshot.docs) {
      final data = doc.data();
      totalBytes = _estimateDocSize(data);

      if (totalBytes < safeLimit) {
        targetDoc = doc.reference;
        targetData = data;
        break;
      }
    }

    // 🆕 Step 2: If none found, create a new doc
    if (targetDoc == null) {
      targetDoc = collection.doc("batch_${snapshot.size + 1}");
      targetData = {"images": []};
    }

    // 🖼️ Step 3: Append images until doc is near limit
    final images = List<Map<String, dynamic>>.from(targetData!["images"]);

    for (final photo in photos) {
      final encoded = photo.buffer.asUint8List();
      images.add({"data": encoded, "timestamp": DateTime.now().toIso8601String()});
    }

    await targetDoc.set({"images": images});

    print("✅ Saved ${photos.length} images to ${targetDoc.id}");
  }

  /// Retrieve all images for a given user
  Future<List<Uint8List>> getAllImages(String employeeId) async {
    final collection = _imagesRef.doc("users_photos").collection(employeeId);
    final snapshot = await collection.get();

    final List<Uint8List> allPhotos = [];

    for (final doc in snapshot.docs) {
      final data = doc.data();
      final images = data["images"] as List<dynamic>;
      for (final img in images) {
        allPhotos.add(Uint8List.fromList(List<int>.from(img["data"])));
      }
    }

    return allPhotos;
  }

  /// Estimate document size for Firestore (rough)
  int _estimateDocSize(Map<String, dynamic> data) {
    int total = 0;
    for (final entry in data.entries) {
      if (entry.value is List) {
        for (final item in (entry.value as List)) {
          if (item is Map && item["data"] is Uint8List) {
            total += (item["data"] as Uint8List).length;
          }
        }
      }
    }
    return total;
  }
}
