import '../models/user_model.dart';
import '../services/user_service.dart';
import '../mappers/user_mapper.dart';

class UserRepository {
  final UserService _service;

  UserRepository(this._service);

  // -------------------------
  // Collection builder
  // -------------------------
  String _collection(String tenantId) => '${tenantId}_Users';

  // -------------------------
  // Get single user
  // -------------------------
  Future<UserModel?> getUserById(String tenantId, String id) async {
    final doc = await _service.firestore
        .collection(_collection(tenantId))
        .doc(id)
        .get();

    final data = doc.data();
    if (data == null) return null;

    return UserMapper.fromFirestore(data, doc.id);
  }

  // -------------------------
  // Get all users
  // -------------------------
  Future<List<UserModel>> getAllUsers(String tenantId) async {
    print("🔥 COLLECTION: ${_collection(tenantId)}");

    final snapshot = await _service.firestore
        .collection(_collection(tenantId))
        .get();

    print("🔥 DOC COUNT: ${snapshot.docs.length}");

    return snapshot.docs
        .map((doc) => UserMapper.fromFirestore(doc.data(), doc.id))
        .toList();
  }

  // -------------------------
  // Add user
  // -------------------------
  Future<void> addUser(String tenantId, UserModel user) async {
    await _service.firestore
        .collection(_collection(tenantId))
        .doc(user.id)
        .set(UserMapper.toFirestore(user));
  }

  // -------------------------
  // Update user
  // -------------------------
  Future<void> updateUser(String tenantId, UserModel user) async {
    await _service.firestore
        .collection(_collection(tenantId))
        .doc(user.id)
        .update(UserMapper.toFirestore(user));
  }

  // -------------------------
  // Delete user
  // -------------------------
  Future<void> deleteUser(String tenantId, String userId) async {
    await _service.firestore
        .collection(_collection(tenantId))
        .doc(userId)
        .delete();
  }
}