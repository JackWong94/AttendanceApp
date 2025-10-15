import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String id;
  final String name;
  final String employeeId;
  final List<List<double>> faceEmbeddings;
  final List<double> embedding;

  UserModel({
    required this.id,
    required this.name,
    required this.employeeId,
    this.faceEmbeddings = const [],
    this.embedding = const [],
  });

  /// Create a copy with optional changes
  UserModel copyWith({
    String? name,
    String? employeeId,
    List<List<double>>? faceEmbeddings,
    List<double>? embedding,
  }) {
    return UserModel(
      id: id,
      name: name ?? this.name,
      employeeId: employeeId ?? this.employeeId,
      faceEmbeddings: faceEmbeddings ?? this.faceEmbeddings,
      embedding: embedding ?? this.embedding,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'employeeId': employeeId,
      // Store as arrays instead of comma-separated strings
      'faceEmbeddings': faceEmbeddings,
    };
  }

  static UserModel fromDocument(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    if (data == null) {
      throw Exception("⚠️ Empty user document: ${doc.id}");
    }

    final List<List<double>> embeddings = [];

    if (data['faceEmbeddings'] != null) {
      for (var e in data['faceEmbeddings'] as List<dynamic>) {
        // ✅ Case 1: Already stored as List<num> (new format)
        if (e is List) {
          final numeric = e
              .where((v) => v is num)
              .map((v) => (v as num).toDouble())
              .toList();
          if (numeric.isNotEmpty) embeddings.add(numeric);
        }

        // ✅ Case 2: Old format (comma-separated string)
        else if (e is String) {
          final values = e
              .split(',')
              .map((s) => double.tryParse(s.trim()))
              .where((v) => v != null && v.isFinite)
              .map((v) => v!)
              .toList();
          if (values.isNotEmpty) embeddings.add(values);
        }

        // ✅ Unknown format (debug log only)
        else {
          print("⚠️ Unknown embedding format for ${doc.id}: $e");
        }
      }
    }

    // ✅ Pick the first embedding as "primary" if exists
    final List<double> primaryEmbedding = embeddings.isNotEmpty ? embeddings.first : [];

    return UserModel(
      id: doc.id,
      name: data['name'] ?? doc.id,
      employeeId: data['employeeId'] ?? '',
      faceEmbeddings: embeddings,
      embedding: primaryEmbedding,
    );
  }
}
