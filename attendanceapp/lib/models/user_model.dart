import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String id;
  final String name;
  final String employeeId;
  final List<List<double>> faceEmbeddings;

  /// 🔐 Optional hashed password for sub-page authorization
  final String? passwordHash;

  UserModel({
    required this.id,
    required this.name,
    required this.employeeId,
    this.faceEmbeddings = const [],
    this.passwordHash, // new optional field
  });

  /// Create a copy with optional changes
  UserModel copyWith({
    String? name,
    String? employeeId,
    List<List<double>>? faceEmbeddings,
    List<double>? embedding,
    String? passwordHash, // new
  }) {
    return UserModel(
      id: id,
      name: name ?? this.name,
      employeeId: employeeId ?? this.employeeId,
      faceEmbeddings: faceEmbeddings ?? this.faceEmbeddings,
      passwordHash: passwordHash ?? this.passwordHash, // new
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'employeeId': employeeId,
      'faceEmbeddings': faceEmbeddings.map((e) => e.join(',')).toList(),
      if (passwordHash != null) 'passwordHash': passwordHash, // new
    };
  }

  static UserModel fromDocument(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    final List<List<double>> embeddings = [];
    if (data['faceEmbeddings'] != null) {
      for (var e in data['faceEmbeddings'] as List<dynamic>) {
        embeddings.add((e as String)
            .split(',')
            .map((v) => double.parse(v))
            .toList());
      }
    }
    List<double> primaryEmbedding = embeddings.isNotEmpty ? embeddings.first : [];

    return UserModel(
      id: doc.id,
      name: data['name'] ?? doc.id,
      employeeId: data['employeeId'] ?? '',
      faceEmbeddings: embeddings,
      passwordHash: data['passwordHash'], // new
    );
  }
}
