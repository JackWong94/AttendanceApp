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
}
