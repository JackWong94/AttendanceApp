import '../models/user_model.dart';
import '../mappers/user_mapper.dart';
import 'user_service.dart';
import '../utils/password_hasher.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';

class UserModelService {
  static UserModelService? _instance;
  final String tenantId;
  final CollectionReference<Map<String, dynamic>> _usersRef;
  static final _userService = UserService(FirebaseFirestore.instance);

  UserModelService._internal(this.tenantId)
      : _usersRef = FirebaseFirestore.instance
      .collection('tenants')
      .doc(tenantId)
      .collection('users');

  CollectionReference<Map<String, dynamic>> get usersCollection => _usersRef;

  static void init({required String tenantId}) {
    _instance = UserModelService._internal(tenantId);
  }

  static void clear() {
    _instance = null;
  }

  static UserModelService get instance {
    if (_instance == null) {
      throw Exception("UserModelService not initialized yet!");
    }
    return _instance!;
  }

  /// Add new user
  Future<void> addUser(UserModel user) async {
    await _usersRef.doc(user.id).set(UserMapper.toFirestore(user));
  }

  /// Get all users
  Future<List<UserModel>> getAllUsers() async {
    final snapshot = await _usersRef.get();

    return snapshot.docs
        .where((doc) => doc.data() != null)
        .map((doc) => UserMapper.fromFirestore(doc.data()!, doc.id))
        .toList();
  }

  /// Get user by ID
  Future<UserModel?> getUserById(String id) async {
    final doc = await _usersRef.doc(id).get();
    if (!doc.exists) return null;
    return UserMapper.fromFirestore(doc.data()!, doc.id);
  }

  Future<bool> isNameExists(String name) async {
    final query = await _usersRef.where('name', isEqualTo: name).limit(1).get();
    return query.docs.isNotEmpty;
  }

  Future<bool> isEmployeeIdExists(String employeeId) async {
    final doc = await _usersRef.doc(employeeId).get();
    return doc.exists;
  }

  DocumentReference<Map<String, dynamic>> getUserDocRef(String userId) {
    return _usersRef.doc(userId);
  }

  /// Update user data (merge)
  Future<void> updateUser(UserModel user) async {
    await _userService.updateUser(user);
  }

  Future<void> deleteUser(String userId) async {
    await _usersRef.doc(userId).delete();
  }

  // =====================================================
  // 🔐 PASSWORD MANAGEMENT (NEW)
  // =====================================================
  /// Set / change password using async isolate hashing
  Future<void> setUserPassword({
    required String userId,
    required String plainPassword,
  }) async {
    // 🔹 Hash password off main thread
    final hash = await PasswordHasher.hashAsync(plainPassword);

    // 🔹 Save hash to Firestore
    await _usersRef.doc(userId).set(
      {'passwordHash': hash},
      SetOptions(merge: true),
    );
  }
  /// Verify password
  Future<bool> verifyUserPassword({
    required String userId,
    required String plainPassword,
  }) async {
    final doc = await _usersRef.doc(userId).get();
    if (!doc.exists) return false;

    final hash = doc.data()?['passwordHash'];
    if (hash == null || hash is! String) return false;

    return PasswordHasher.verify(plainPassword, hash);
  }

  /// Check if password exists
  Future<bool> hasPassword(String userId) async {
    final doc = await _usersRef.doc(userId).get();
    return doc.exists && doc.data()?['passwordHash'] != null;
  }
}
