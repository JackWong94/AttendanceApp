import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import '../mappers/user_mapper.dart';

class UserService {
  final FirebaseFirestore firestore;

  UserService(this.firestore);

  Future<UserModel?> getUser(String id) async {
    final doc = await firestore.collection('users').doc(id).get();

    final data = doc.data();
    if (data == null) return null;

    return UserMapper.fromFirestore(data, doc.id);
  }

  Future<List<UserModel>> getAllUsers() async {
    final snapshot = await firestore.collection('users').get();

    return snapshot.docs
        .where((doc) => doc.data() != null)
        .map((doc) => UserMapper.fromFirestore(doc.data()!, doc.id))
        .toList();
  }

  Future<void> updateUser(UserModel user) async {
    await firestore.collection('users').doc(user.id).update(
      UserMapper.toFirestore(user),
    );
  }
}