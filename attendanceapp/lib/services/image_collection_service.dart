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

  /// ------------------------------
  /// RANGE QUERY METHODS
  /// ------------------------------

  /// Returns a list of Firestore document names like attendancePhoto_YYYYMM_X
  Future<List<String>> getAttendancePhotoDocsInRange({
    required String indexName,
    required DateTime start,
    required DateTime end,
  }) async {
    final indexData = await _getIndexDoc(indexName);
    if (indexData.isEmpty) return [];

    final Map<String, String> entryIndex =
    Map<String, String>.from(indexData["index"] ?? {});

    // 1️⃣ Build month-based doc prefixes
    final List<String> monthDocPrefixes = [];
    DateTime iter = DateTime(start.year, start.month);
    while (!iter.isAfter(end)) {
      final prefix =
          "attendancePhoto_${iter.year}${iter.month.toString().padLeft(2, '0')}";
      monthDocPrefixes.add(prefix);
      iter = DateTime(iter.year, iter.month + 1);
    }

    // 2️⃣ Collect all docNames that match those prefixes
    final Set<String> relevantDocs = {};
    entryIndex.forEach((entryKey, docName) {
      if (monthDocPrefixes.any((prefix) => docName.startsWith(prefix))) {
        relevantDocs.add(docName);
      }
    });

    final List<String> sortedDocs = relevantDocs.toList()
      ..sort((a, b) => a.compareTo(b)); // optional: sort by name
    print("Relevant attendance photo docs: $sortedDocs");

    return sortedDocs;
  }

  /// Delete multiple attendance photo documents
  Future<void> deleteAttendancePhotoDocs({
    required String indexName,
    required List<String> docNames,
  }) async {
    final collection = FirebaseFirestore.instance.collection(collectionPath);
    final indexRef = collection.doc(indexName);
    for (final docName in docNames) {
      // 1️⃣ Delete the document itself
      await collection.doc(docName).delete();

      // 2️⃣ Remove all entries from the index and counts
      final indexSnap = await indexRef.get();
      if (!indexSnap.exists) continue;

      final indexData = indexSnap.data() ?? {};
      final Map<String, String> entryIndex =
      Map<String, String>.from(indexData["index"] ?? {});
      print("Entry index: $entryIndex");

      final keysToDelete = entryIndex.entries
          .where((e) => e.value == docName)
          .map((e) => e.key)
          .toList();

      final Map<String, dynamic> indexUpdates = {};
      for (final key in keysToDelete) {
        indexUpdates["index.$key"] = FieldValue.delete();
      }
      indexUpdates["counts.$docName"] = FieldValue.delete();

      await indexRef.update(indexUpdates);

      debug.log("🗑️ Deleted entire document $docName with ${keysToDelete.length} entries");
    }
  }
}
