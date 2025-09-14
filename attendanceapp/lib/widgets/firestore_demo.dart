import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreDemo extends StatefulWidget {
  const FirestoreDemo({super.key});

  @override
  State<FirestoreDemo> createState() => _FirestoreDemoState();
}

class _FirestoreDemoState extends State<FirestoreDemo> {
  final CollectionReference users =
  FirebaseFirestore.instance.collection('users');

  @override
  void initState() {
    super.initState();
    //_addUser();      // Add a test user
    _listenUsers();  // Listen in real-time
  }

  Future<void> _addUser() async {
    try {
      await users.add({
        'name': 'Jack Wong',
        'email': 'jack@example.com',
        'createdAt': DateTime.now(),
      });
      print('User added successfully!');
    } catch (e) {
      print('Error adding user: $e');
    }
  }

  void _listenUsers() {
    users.snapshots().listen((snapshot) {
      print('--- Firestore Users ---');
      for (var doc in snapshot.docs) {
        print('User: ${doc.data()}');
      }
      print('-----------------------');
    }, onError: (error) {
      print('Error listening to users: $error');
    });
  }

  @override
  Widget build(BuildContext context) {
    return const Center(child: Text('Check console for Firestore output'));
  }
}
