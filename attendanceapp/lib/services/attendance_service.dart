import 'package:cloud_firestore/cloud_firestore.dart';
import 'user_model_service.dart';
import '../models/user_model.dart';
import 'date_service.dart';

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

  /// Fetch attendance for a single day
  Future<Map<String, String>> fetchAttendance({
    required UserModel user,
    required String date,
  }) async {
    final tenantId = UserModelService.instance.tenantId;
    final usersCollection = _firestore.collection('${tenantId}_Users');
    final attendanceCollection = _firestore.collection('${tenantId}_Attendance');

    final userRef = usersCollection.doc(user.id);
    final snapshot = await attendanceCollection
        .where('user', isEqualTo: userRef)
        .where('date', isEqualTo: date)
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) return {'scanIn': 'N/A', 'scanOut': 'N/A'};

    final data = snapshot.docs.first.data();
    final scanIn = data['scanIn'] != null
        ? DateService.toDisplayTime((data['scanIn'] as Timestamp).toDate())
        : 'N/A';
    final scanOut = data['scanOut'] != null
        ? DateService.toDisplayTime((data['scanOut'] as Timestamp).toDate())
        : 'N/A';

    return {'scanIn': scanIn, 'scanOut': scanOut};
  }

  /// Fetch attendance for a whole month
  Future<Map<String, Map<String, String>>> fetchMonthlyAttendance({
    required UserModel user,
    required DateTime month,
  }) async {
    final tenantId = UserModelService.instance.tenantId;
    final usersCollection = _firestore.collection('${tenantId}_Users');
    final attendanceCollection = _firestore.collection('${tenantId}_Attendance');

    final userRef = usersCollection.doc(user.id);

    final int totalDays = DateService.getDaysInMonth(month.year, month.month);
    Map<String, Map<String, String>> result = {};

    for (int i = 1; i <= totalDays; i++) {
      final date = DateTime(month.year, month.month, i);
      final dateStr = DateService.toStorageDate(date);

      final snapshot = await attendanceCollection
          .where('user', isEqualTo: userRef)
          .where('date', isEqualTo: dateStr)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) {
        result[dateStr] = {'scanIn': 'N/A', 'scanOut': 'N/A'};
      } else {
        final data = snapshot.docs.first.data();
        final scanIn = data['scanIn'] != null
            ? DateService.toDisplayTime((data['scanIn'] as Timestamp).toDate())
            : 'N/A';
        final scanOut = data['scanOut'] != null
            ? DateService.toDisplayTime((data['scanOut'] as Timestamp).toDate())
            : 'N/A';
        result[dateStr] = {'scanIn': scanIn, 'scanOut': scanOut};
      }
    }

    return result;
  }
}
