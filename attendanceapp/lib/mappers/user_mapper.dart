import '../models/user_model.dart';

class UserMapper {
  static UserModel fromFirestore(Map<String, dynamic> data, String id) {
    return UserModel(
      id: id,
      name: data['name'] ?? '',
      employeeId: data['employeeId'] ?? '',
      faceEmbeddings: (data['faceEmbeddings'] as List?)
          ?.map((e) => List<double>.from(e))
          .toList() ??
          [],
      passwordHash: data['passwordHash'],
    );
  }

  static Map<String, dynamic> toFirestore(UserModel user) {
    return {
      'name': user.name,
      'employeeId': user.employeeId,
      'faceEmbeddings': user.faceEmbeddings,
      if (user.passwordHash != null)
        'passwordHash': user.passwordHash,
    };
  }
}