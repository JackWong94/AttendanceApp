import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:attendanceapp/models/user_model.dart';

class AttendanceService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Scan user (rules enforced)
  Future<void> scanUser({
    required UserModel user,
    required bool isScanIn,
  }) async {
    final userRef = _firestore.collection('users').doc(user.id); // always ref
    final today = DateTime.now();
    final dateStr = "${today.year}-${today.month}-${today.day}";

    final query = await _firestore
        .collection('attendance')
        .where('user', isEqualTo: userRef) // store ref
        .where('date', isEqualTo: dateStr)
        .limit(1)
        .get();

    final timestamp = DateTime.now();

    if (query.docs.isEmpty) {
      if (!isScanIn) throw Exception("❌ ${user.name} cannot scan out without scanning in today");

      await _firestore.collection('attendance').add({
        'user': userRef,               // store reference
        'userName': user.name,         // store name for easy reading
        'date': dateStr,
        'scanIn': Timestamp.fromDate(timestamp),
      });
    } else {
      final docRef = query.docs.first.reference;
      final data = query.docs.first.data();

      if (isScanIn) {
        if (data['scanIn'] != null) throw Exception("❌ ${user.name} already scanned in today");
        if (data['scanOut'] != null) throw Exception("❌ ${user.name} cannot scan in after scanning out today");

        await docRef.set({'scanIn': Timestamp.fromDate(timestamp)}, SetOptions(merge: true));
      } else {
        if (data['scanIn'] == null) throw Exception("❌ ${user.name} must scan in before scanning out");
        if (data['scanOut'] != null) throw Exception("❌ ${user.name} already scanned out today");

        await docRef.set({'scanOut': Timestamp.fromDate(timestamp)}, SetOptions(merge: true));
      }
    }
  }
}
