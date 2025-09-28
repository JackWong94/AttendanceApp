//Data migration script example
import 'package:cloud_firestore/cloud_firestore.dart';

Future<void> migrateUsers() async {
  final firestore = FirebaseFirestore.instance;

  final oldCollection = firestore.collection('pro_CKHW_Users');
  final newCollection = firestore.collection('dev_Users');

  final snapshot = await oldCollection.get();

  for (final doc in snapshot.docs) {
    final data = Map<String, dynamic>.from(doc.data());

    // Remove "migratedAt" if exists
    data.remove('migratedAt');

    // Keep same docId (e.g., EMP0001)
    final userId = doc.id;

    await newCollection.doc(userId).set(data);

    print("✅ Migrated user $userId");
  }

  print("🎉 Users migration finished.");
}

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

Future<void> copyUsersDevToPro() async {
  final firestore = FirebaseFirestore.instance;

  final devCollection = firestore.collection('dev_Users');
  final proCollection = firestore.collection('pro_CKHW_Users');

  final snapshot = await devCollection.get();

  for (final doc in snapshot.docs) {
    final data = Map<String, dynamic>.from(doc.data());

    // Just copy as-is
    await proCollection.doc(doc.id).set(data);

    print("✅ Copied user ${doc.id}");
  }

  print("🎉 Finished copying Users from dev_Users → pro_CKHW_Users");
}

Future<void> copyAttendanceDevToPro() async {
  final firestore = FirebaseFirestore.instance;

  final devCollection = firestore.collection('dev_Attendance');
  final proCollection = firestore.collection('pro_CKHW_Attendance');

  final snapshot = await devCollection.get();

  for (final doc in snapshot.docs) {
    final data = Map<String, dynamic>.from(doc.data());

    // Update "user" field reference
    if (data['user'] != null && data['user'] is DocumentReference) {
      final ref = data['user'] as DocumentReference;
      final userId = ref.id;
      data['user'] = firestore.doc('/pro_CKHW_Users/$userId');
    }

    await proCollection.doc(doc.id).set(data);

    print("✅ Copied attendance ${doc.id}");
  }

  print("🎉 Finished copying Attendance from dev_Attendance → pro_CKHW_Attendance");
}


Future<void> runMigrationScript() async {
  print("\u26A0 WARNING YOU ARE RUNNING MIGRATION SCRIPT NOW \u26A0");
  //await migrateUsers();
  //await migrateAttendance();
  //await copyUsersDevToPro();
  //await copyAttendanceDevToPro();
}