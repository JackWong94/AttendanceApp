import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String id;
  final String name;
  final String employeeId;
  final List<List<double>> faceEmbeddings;
  final List<double> embedding;
  final bool isDeleted; // new flag

  UserModel({
    required this.id,
    required this.name,
    required this.employeeId,
    this.faceEmbeddings = const [],
    this.embedding = const [],
    this.isDeleted = false,
  });

  /// Create a copy with optional changes
  UserModel copyWith({
    String? name,
    String? employeeId,
    List<List<double>>? faceEmbeddings,
    List<double>? embedding,
    bool? isDeleted,
  }) {
    return UserModel(
      id: id,
      name: name ?? this.name,
      employeeId: employeeId ?? this.employeeId,
      faceEmbeddings: faceEmbeddings ?? this.faceEmbeddings,
      embedding: embedding ?? this.embedding,
      isDeleted: isDeleted ?? this.isDeleted,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'employeeId': employeeId,
      'faceEmbeddings': faceEmbeddings.map((e) => e.join(',')).toList(),
      'isDeleted': isDeleted,
    };
  }

  static UserModel fromDocument(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    final List<List<double>> embeddings = [];
    if (data['faceEmbeddings'] != null) {
      for (var e in data['faceEmbeddings'] as List<dynamic>) {
        embeddings.add((e as String).split(',').map((v) => double.parse(v)).toList());
      }
    }
    List<double> primaryEmbedding = embeddings.isNotEmpty ? embeddings.first : [];

    return UserModel(
      id: doc.id,
      name: data['name'] ?? doc.id,
      employeeId: data['employeeId'] ?? '',
      faceEmbeddings: embeddings,
      embedding: primaryEmbedding,
      isDeleted: data['isDeleted'] ?? false,
    );
  }
}
