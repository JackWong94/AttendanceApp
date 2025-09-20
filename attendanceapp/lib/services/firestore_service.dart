import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreService {
  final String tenantId;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  FirestoreService({required this.tenantId});

  CollectionReference<Map<String, dynamic>> get users =>
      _firestore.collection('${tenantId}_Users');

  CollectionReference<Map<String, dynamic>> get attendance =>
      _firestore.collection('${tenantId}_Attendance');
}
