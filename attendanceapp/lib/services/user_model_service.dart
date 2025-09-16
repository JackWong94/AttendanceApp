import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';

class UserModelService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final CollectionReference<Map<String, dynamic>> _usersRef =
  FirebaseFirestore.instance.collection('users');

  // Get user by docId
  Future<UserModel> getUserById(String id) async {
    final doc = await _usersRef.doc(id).get();
    print("User data: ${doc.data()}");
    return UserModel.fromDocument(doc);
  }

  // Add a new user
  Future<void> addUser(UserModel user) async {
    await _usersRef.doc(user.id).set(user.toMap());
  }

  // List all users
  Future<List<UserModel>> getAllUsers() async {
    final snapshot = await _usersRef.get();
    return snapshot.docs.map((doc) => UserModel.fromDocument(doc)).toList();
  }

  // Get DocumentReference for a user
  DocumentReference<Map<String, dynamic>> ref(String id) {
    return _usersRef.doc(id);
  }
}
