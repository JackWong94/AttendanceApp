import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/attendance_model.dart';
import 'user_model_service.dart';
import 'date_service.dart';

class AttendanceModelService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String tenantId;

  AttendanceModelService._internal(this.tenantId);

  static AttendanceModelService? _instance;

  /// Singleton instance
  static AttendanceModelService get instance {
    if (_instance == null) {
      final tenantId = UserModelService.instance.tenantId;
      _instance = AttendanceModelService._internal(tenantId);
    }
    return _instance!;
  }

  /// Reference to the tenant's attendance collection
  CollectionReference<Map<String, dynamic>> get _attendanceRef =>
      _firestore.collection('${tenantId}_Attendance');

  /// Set attendance (create or update deterministically)
  Future<void> setAttendance(Attendance attendance) async {
    if (attendance.id.isEmpty) {
      throw Exception("Attendance must have a valid ID before saving.");
    }
    await _attendanceRef.doc(attendance.id).set(
      attendance.toMap(),
      SetOptions(merge: true), // will update if exists, create if not
    );
  }

  /// Fetch attendance for a user for a specific date
  Future<Attendance?> fetchAttendanceForDate({
    required String userId,
    required String date,
  }) async {
    final docId = "${userId}_$date";
    final snapshot = await _attendanceRef.doc(docId).get();

    if (!snapshot.exists) return null;
    return Attendance.fromDoc(snapshot);
  }

  /// Fetch all attendance for a user for a month
  Future<List<Attendance>> fetchMonthlyAttendance({
    required String userId,
    required DateTime month,
  }) async {
    final startOfMonth = DateTime(month.year, month.month, 1);
    final endOfMonth = DateTime(month.year, month.month + 1, 0);

    final snapshots = await _attendanceRef
        .where('user', isEqualTo: UserModelService.instance.getUserDocRef(userId))
        .where('date', isGreaterThanOrEqualTo: DateService.toStorageDate(startOfMonth))
        .where('date', isLessThanOrEqualTo: DateService.toStorageDate(endOfMonth))
        .orderBy('date')
        .get();

    return snapshots.docs.map((doc) => Attendance.fromDoc(doc)).toList();
  }

  /// Fetch all attendance for a user between startDate and endDate
  Future<List<Attendance>> fetchStartToEndDateAttendanceForUser({
    required DocumentReference userRef,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final snapshots = await _attendanceRef
        .where('user', isEqualTo: userRef)
        .where('date', isGreaterThanOrEqualTo: DateService.toStorageDate(startDate))
        .where('date', isLessThanOrEqualTo: DateService.toStorageDate(endDate))
        .orderBy('date')
        .get();

    return snapshots.docs.map((doc) => Attendance.fromDoc(doc)).toList();
  }

  /// Fetch attendance for all users in a date range
  Future<List<Attendance>> fetchAttendanceForMonthAllUsers({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final snapshots = await _attendanceRef
        .where('date', isGreaterThanOrEqualTo: DateService.toStorageDate(startDate))
        .where('date', isLessThanOrEqualTo: DateService.toStorageDate(endDate))
        .orderBy('date')
        .get();

    return snapshots.docs.map((doc) => Attendance.fromDoc(doc)).toList();
  }
}
