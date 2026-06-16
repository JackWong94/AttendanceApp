import '../models/user_model.dart';
import 'package:attendanceapp/configs_and_tools/debug.dart';

Debug debug = Debug(module: "user_mapper", enable: true);

class UserMapper {
  static UserModel fromFirestore(Map<String, dynamic> data, String id) {
    debug.log("🔥 FROM FIRESTORE: ${data['name']}");
    return UserModel(
      id: id,
      name: data['name'] ?? '',
      employeeId: data['employeeId'] ?? '',
      faceEmbeddings: _parseEmbeddings(data['faceEmbeddings']),
      passwordHash: data['passwordHash'] ?? '',
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

  static List<List<double>> _parseEmbeddings(dynamic value) {
    if (value is! List) return [];

    return value.map<List<double>>((embedding) {
      if (embedding is String) {
        return embedding
            .split(',')
            .map((e) => double.tryParse(e.trim()) ?? 0.0)
            .toList();
      }

      if (embedding is List) {
        return embedding
            .map((e) => (e as num).toDouble())
            .toList();
      }

      return <double>[];
    }).toList();
  }
}