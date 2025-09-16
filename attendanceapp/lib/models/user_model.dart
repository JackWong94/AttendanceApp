import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String id;
  final String name;
  final String email;
  final String employeeId;
  final List<List<double>> faceEmbeddings; // multiple embeddings per user
  final List<double> embedding; // optional primary embedding for recognition

  UserModel({
    required this.id,
    required this.name,
    required this.email,
    required this.employeeId,
    this.faceEmbeddings = const [],
    this.embedding = const [],
  });

  /// Convert to Firestore map
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'email': email,
      'employeeId': employeeId,
      'faceEmbeddings': faceEmbeddings
          .map((e) => e.join(',')) // store each embedding as CSV string
          .toList(),
    };
  }

  /// Create UserModel from Firestore document
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

    // optional primary embedding for quick recognition
    List<double> primaryEmbedding =
    embeddings.isNotEmpty ? embeddings.first : [];

    return UserModel(
      id: doc.id,
      name: data['name'] ?? doc.id,
      email: data['email'] ?? '',
      employeeId: data['employeeId'] ?? '',
      faceEmbeddings: embeddings,
      embedding: primaryEmbedding,
    );
  }
}
