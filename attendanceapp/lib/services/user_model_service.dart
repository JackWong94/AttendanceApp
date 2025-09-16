import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';

class UserModelService {
  final CollectionReference<Map<String, dynamic>> usersRef =
  FirebaseFirestore.instance.collection('users');

  /// Add new user
  Future<void> addUser(UserModel user) async {
    await usersRef.doc(user.id).set(user.toMap());
  }

  /// Get all users
  Future<List<UserModel>> getAllUsers() async {
    final snapshot = await usersRef.get();
    return snapshot.docs
        .map((doc) => UserModel.fromDocument(doc))
        .toList();
  }

  /// Get user by Firestore document ID
  Future<UserModel?> getUserById(String id) async {
    final doc = await usersRef.doc(id).get();
    if (!doc.exists) return null;
    return UserModel.fromDocument(doc);
  }

  /// Check if a user name already exists
  Future<bool> isNameExists(String name) async {
    final query = await usersRef.where('name', isEqualTo: name).limit(1).get();
    return query.docs.isNotEmpty;
  }

  /// Check if an employee ID already exists
  Future<bool> isEmployeeIdExists(String employeeId) async {
    final doc = await usersRef.doc(employeeId).get();
    return doc.exists;
  }
}
