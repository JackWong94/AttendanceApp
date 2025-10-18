import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String id;
  final String name;
  final String employeeId;
  final List<List<double>> faceEmbeddings;

  UserModel({
    required this.id,
    required this.name,
    required this.employeeId,
    this.faceEmbeddings = const [],
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
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'employeeId': employeeId,
      'faceEmbeddings': faceEmbeddings.map((e) => e.join(',')).toList(),
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
    );
  }
}
