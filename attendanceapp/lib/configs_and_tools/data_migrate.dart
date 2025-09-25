/*
Dataigration script example
import 'package:cloud_firestore/cloud_firestore.dart';


Future<void> migrateAttendance() async {
  final firestore = FirebaseFirestore.instance;

  final oldCollection = firestore.collection('pro_CKHW_Attendance');
  final newCollection = firestore.collection('dev_Attendance');

  final snapshot = await oldCollection.get();

  for (final doc in snapshot.docs) {
    final data = doc.data();

    final String date = data['date'] ?? '';
    final userRef = data['user'];

    // Build scanIns (always: normal → lunch → ot)
    final List<Map<String, dynamic>> scanIns = [];
    if (data['scanIn'] != null) {
      scanIns.add({'time': data['scanIn'], 'imageUrl': 'cameraImageUrl'});
    }
    if (data['scanInLunch'] != null) {
      scanIns.add({'time': data['scanInLunch'], 'imageUrl': 'cameraImageUrl'});
    }
    if (data['scanInOt'] != null) {
      scanIns.add({'time': data['scanInOt'], 'imageUrl': 'cameraImageUrl'});
    }

    // Build scanOuts (lunch → normal → ot)  ✅ FIXED ORDER
    final List<Map<String, dynamic>> scanOuts = [];
    if (data['scanOutLunch'] != null) {
      scanOuts.add({'time': data['scanOutLunch'], 'imageUrl': 'cameraImageUrl'});
    }
    if (data['scanOut'] != null) {
      scanOuts.add({'time': data['scanOut'], 'imageUrl': 'cameraImageUrl'});
    }
    if (data['scanOutOt'] != null) {
      scanOuts.add({'time': data['scanOutOt'], 'imageUrl': 'cameraImageUrl'});
    }

    // New docId format: date_userId
    final userId = userRef.id; // from /pro_CKHW_Users/EMP0001 → EMP0001
    final newDocId = "${date}_$userId";

    await newCollection.doc(newDocId).set({
      'date': date,
      'user': FirebaseFirestore.instance.doc('/dev_Users/$userId'),
      'scanIns': scanIns,
      'scanOuts': scanOuts,
    });

    print("✅ Migrated $newDocId");
  }

  print("🎉 Attendance migration finished.");
}
*/