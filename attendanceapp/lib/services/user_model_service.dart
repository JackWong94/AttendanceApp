import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';

class UserModelService {
  static UserModelService? _instance;
  final String tenantId;
  final CollectionReference<Map<String, dynamic>> _usersRef;

  UserModelService._internal(this.tenantId)
      : _usersRef = FirebaseFirestore.instance.collection('${tenantId}_Users');

  // Public getter for users collection
  CollectionReference<Map<String, dynamic>> get usersCollection => _usersRef;

  /// Initialize singleton with tenantId
  static void init({required String tenantId}) {
    _instance = UserModelService._internal(tenantId); // overwrite old instance
  }

  /// Clear instance (call on logout)
  static void clear() {
    _instance = null;
  }

  /// Get singleton instance
  static UserModelService get instance {
    if (_instance == null) {
      throw Exception("UserModelService not initialized yet!");
    }
    return _instance!;
  }

  /// Add new user
  Future<void> addUser(UserModel user) async {
    await _usersRef.doc(user.id).set(user.toMap());
  }

  /// Get all users
  Future<List<UserModel>> getAllUsers() async {
    final snapshot = await _usersRef.get();
    return snapshot.docs.map((doc) => UserModel.fromDocument(doc)).toList();
  }

  /// Get user by Firestore document ID
  Future<UserModel?> getUserById(String id) async {
    final doc = await _usersRef.doc(id).get();
    if (!doc.exists) return null;
    return UserModel.fromDocument(doc);
  }

  /// Check if a user name already exists
  Future<bool> isNameExists(String name) async {
    final query = await _usersRef.where('name', isEqualTo: name).limit(1).get();
    return query.docs.isNotEmpty;
  }

  /// Check if an employee ID already exists
  Future<bool> isEmployeeIdExists(String employeeId) async {
    final doc = await _usersRef.doc(employeeId).get();
    return doc.exists;
  }

  DocumentReference<Map<String, dynamic>> getUserDocRef(String userId) {
    return _usersRef.doc(userId);
  }
}
