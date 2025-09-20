import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import 'date_service.dart';
import 'user_model_service.dart';

class AttendanceService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Scan user attendance
  Future<void> scanUser({required UserModel user, required bool isScanIn}) async {
    final tenantId = UserModelService.instance.tenantId;

    final usersCollection = _firestore.collection('${tenantId}_Users');
    final attendanceCollection = _firestore.collection('${tenantId}_Attendance');

    final userRef = usersCollection.doc(user.id);
    final today = DateTime.now();
    final dateStr = DateService.toStorageDate(today);

    final query = await attendanceCollection
        .where('user', isEqualTo: userRef)
        .where('date', isEqualTo: dateStr)
        .limit(1)
        .get();

    final timestamp = DateTime.now();

    if (query.docs.isEmpty) {
      if (!isScanIn) throw Exception("❌ ${user.name} cannot scan out without scanning in today");

      await attendanceCollection.add({
        'user': userRef,
        'userName': user.name,
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
