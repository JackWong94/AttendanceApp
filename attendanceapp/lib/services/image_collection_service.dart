import 'dart:convert';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:attendanceapp/configs_and_tools/debug.dart';
import 'package:uuid/uuid.dart';

Debug debug = Debug(module: "image_collection_service", enable: true);

/// ------------------------------------------------------
/// ImageCollectionService
/// ------------------------------------------------------
/// Manages Firestore-stored image collections with automatic
/// document splitting when hitting max entries.
///
/// Structure example:
///   <tenantId>_photos/
///       user_index
///       user_1, user_2, ...
///       attendance_index
///       attendance_1, attendance_2, ...
/// ------------------------------------------------------
class ImageCollectionService {
  final String tenantId;
  final String baseCollection;
  final int maxEntriesPerDoc;

  final _uuid = const Uuid();

  ImageCollectionService({
    required this.tenantId,
    required this.baseCollection,
    required this.maxEntriesPerDoc,
  });

  String get collectionPath => "${tenantId}_Photos";

  /// ------------------------------
  /// INTERNAL HELPERS
  /// ------------------------------

  Future<Map<String, dynamic>> _getIndexDoc(String indexName) async {
    final indexRef =
    FirebaseFirestore.instance.collection(collectionPath).doc(indexName);
    final snapshot = await indexRef.get();
    return snapshot.data() ?? {};
  }

  Future<(String, int)> _getTargetDoc(
      String indexName,
      String defaultPrefix,
      ) async {
    final data = await _getIndexDoc(indexName);
    String targetDoc = "${defaultPrefix}_1";
    int currentCount = 0;

    if (data.isNotEmpty) {
      final lastDoc = data["lastDoc"] ?? targetDoc;
      targetDoc = lastDoc;
      currentCount = (data["counts"]?[lastDoc] ?? 0) as int;
    }
    debug.log("Target doc: $targetDoc, current count: $currentCount");
    debug.log("Max entries per doc: $maxEntriesPerDoc");

    if (currentCount >= maxEntriesPerDoc) {
      debug.log("Reached max entries. Creating new document...");
      final nextIndex = int.parse(targetDoc.split('_').last) + 1;
      targetDoc = "${defaultPrefix}_$nextIndex";
      currentCount = 0;
    }

    return (targetDoc, currentCount);
  }

  /// ------------------------------
  /// CORE CRUD METHODS
  /// ------------------------------

  Future<void> saveEntry({
    required String indexName,
    required String docPrefix,
    required String entryKey,
    required Map<String, dynamic> data,
  }) async {
    final (targetDoc, currentCount) = await _getTargetDoc(indexName, docPrefix);

    final collection = FirebaseFirestore.instance.collection(collectionPath);
    final docRef = collection.doc(targetDoc);
    final indexRef = collection.doc(indexName);

    await docRef.set({entryKey: data}, SetOptions(merge: true));

    await indexRef.set({
      "index": {entryKey: targetDoc},
      "counts": {targetDoc: currentCount + 1},
      "lastDoc": targetDoc,
    }, SetOptions(merge: true));

    debug.log("✅ Saved image $entryKey in $targetDoc");
  }

  Future<Map<String, dynamic>?> getEntry({
    required String indexName,
    required String entryKey,
  }) async {
    final indexRef =
    FirebaseFirestore.instance.collection(collectionPath).doc(indexName);
    final indexSnap = await indexRef.get();
    if (!indexSnap.exists) return null;

    final targetDocName = indexSnap.data()?["index"]?[entryKey];
    if (targetDocName == null) return null;

    final targetDoc = await FirebaseFirestore.instance
        .collection(collectionPath)
        .doc(targetDocName)
        .get();
    return targetDoc.data()?[entryKey];
  }

  Future<void> deleteEntry({
    required String indexName,
    required String entryKey,
  }) async {
    final indexRef =
    FirebaseFirestore.instance.collection(collectionPath).doc(indexName);
    final indexSnap = await indexRef.get();
    if (!indexSnap.exists) return;

    final targetDocName = indexSnap.data()?["index"]?[entryKey];
    if (targetDocName == null) return;

    final docRef = FirebaseFirestore.instance
        .collection(collectionPath)
        .doc(targetDocName);
    await docRef.update({entryKey: FieldValue.delete()});
    await indexRef.set({
      "index": {entryKey: FieldValue.delete()},
      "counts": {targetDocName: FieldValue.increment(-1)}, // ✅ added line
    }, SetOptions(merge: true));

    debug.log("🗑️ Deleted image $entryKey from $targetDocName");
  }
}
