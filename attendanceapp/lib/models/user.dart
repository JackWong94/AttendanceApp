class UserModel {
  final String id;
  final String name;
  final List<double> embedding;

  UserModel({
    required this.id,
    required this.name,
    required this.embedding,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'embedding': embedding.join(","), // store as CSV
    };
  }

  static UserModel fromMap(Map<String, dynamic> map) {
    return UserModel(
      id: map['id'],
      name: map['name'],
      embedding: (map['embedding'] as String)
          .split(",")
          .map((e) => double.parse(e))
          .toList(),
    );
  }
}
