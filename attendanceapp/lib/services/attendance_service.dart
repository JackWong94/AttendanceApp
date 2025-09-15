import 'package:cloud_firestore/cloud_firestore.dart';

class AttendanceService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Scan user (rules enforced)
  Future<void> scanUser({
    required DocumentReference userRef,
    required bool isScanIn,
  }) async {
    final today = DateTime.now();
    final dateStr = "${today.year}-${today.month}-${today.day}";
    final userId = userRef.id; // Extract user name / ID from DocumentReference

    // Query for today's attendance for this user
    final query = await _firestore
        .collection('attendance')
        .where('user', isEqualTo: userRef)
        .where('date', isEqualTo: dateStr)
        .limit(1)
        .get();

    final timestamp = DateTime.now();

    if (query.docs.isEmpty) {
      // No record today yet
      if (!isScanIn) {
        throw Exception("❌ $userId cannot scan out without scanning in today");
      }

      await _firestore.collection('attendance').add({
        'user': userRef,
        'date': dateStr,
        'scanIn': timestamp,
      });
    } else {
      final docRef = query.docs.first.reference;
      final data = query.docs.first.data();

      if (isScanIn) {
        if (data['scanIn'] != null) {
          throw Exception("❌ $userId already scanned in today");
        }
        if (data['scanOut'] != null) {
          throw Exception("❌ $userId cannot scan in after scanning out today");
        }

        await docRef.set({'scanIn': timestamp}, SetOptions(merge: true));
      } else {
        if (data['scanIn'] == null) {
          throw Exception("❌ $userId must scan in before scanning out");
        }
        if (data['scanOut'] != null) {
          throw Exception("❌ $userId already scanned out today");
        }

        await docRef.set({'scanOut': timestamp}, SetOptions(merge: true));
      }
    }
  }
}
