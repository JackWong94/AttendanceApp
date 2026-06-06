import '../models/user_model.dart';
import '../services/user_service.dart';
import '../mappers/user_mapper.dart';

class UserRepository {
  final UserService _service;
  final String tenantId;

  UserRepository(this._service, this.tenantId);

  // -------------------------
  // Collection reference
  // -------------------------
  //String get _collection => '${tenantId}_Users';
  String get _collection => '${tenantId}_Users';

  // -------------------------
  // Get single user
  // -------------------------
  Future<UserModel?> getUserById(String id) async {
    final doc = await _service.firestore
        .collection(_collection)
        .doc(id)
        .get();

    final data = doc.data();
    if (data == null) return null;

    return UserMapper.fromFirestore(data, doc.id);
  }

  // -------------------------
  // Get all users
  // -------------------------
  Future<List<UserModel>> getAllUsers() async {
    final snapshot = await _service.firestore
        .collection(_collection)
        .get();

    return snapshot.docs
        .map((doc) => UserMapper.fromFirestore(doc.data(), doc.id))
        .toList();
  }

  // -------------------------
  // Add user
  // -------------------------
  Future<void> addUser(UserModel user) async {
    await _service.firestore
        .collection(_collection)
        .doc(user.id)
        .set(UserMapper.toFirestore(user));
  }

  // -------------------------
  // Update user
  // -------------------------
  Future<void> updateUser(UserModel user) async {
    await _service.firestore
        .collection(_collection)
        .doc(user.id)
        .update(UserMapper.toFirestore(user));
  }

  // -------------------------
  // Delete user
  // -------------------------
  Future<void> deleteUser(String userId) async {
    await _service.firestore
        .collection(_collection)
        .doc(userId)
        .delete();
  }
}