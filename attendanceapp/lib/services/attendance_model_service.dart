import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/attendance_model.dart';
import 'user_model_service.dart';
import 'date_service.dart';

class AttendanceModelService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String tenantId;

  /// Private reference to the tenant's attendance collection
  CollectionReference<Map<String, dynamic>> get _attendanceRef =>
      _firestore.collection('${tenantId}_Attendance');

  /// Expose attendance collection publicly (read-only)
  CollectionReference<Map<String, dynamic>> get attendanceRef => _attendanceRef;

  AttendanceModelService._internal(this.tenantId);

  static AttendanceModelService? _instance;

  /// Singleton instance
  static AttendanceModelService get instance {
    _instance ??= AttendanceModelService._internal(
      UserModelService.instance.tenantId,
    );
    return _instance!;
  }

  /// Set attendance (create or update deterministically)
  Future<void> setAttendance(Attendance attendance) async {
    if (attendance.id.isEmpty) {
      throw Exception("Attendance must have a valid ID before saving.");
    }
    await _attendanceRef.doc(attendance.id).set(
      attendance.toMap(),
      SetOptions(merge: true), // update if exists, create if not
    );
  }

  /// Fetch attendance for a user on a specific date
  Future<Attendance?> fetchAttendanceForDate({
    required String userId,
    required String date,
  }) async {
    final docId = "${date}_$userId";
    final snapshot = await _attendanceRef.doc(docId).get();

    if (!snapshot.exists) return null;
    return Attendance.fromDoc(snapshot);
  }

  /// Fetch all attendance for a user for a given month
  Future<List<Attendance>> fetchMonthlyAttendance({
    required String userId,
    required DateTime month,
  }) async {
    final startOfMonth = DateTime(month.year, month.month, 1);
    final endOfMonth = DateTime(month.year, month.month + 1, 0);

    final snapshots = await _attendanceRef
        .where(
      'user',
      isEqualTo: UserModelService.instance.getUserDocRef(userId),
    )
        .where(
      'date',
      isGreaterThanOrEqualTo: DateService.toStorageDate(startOfMonth),
    )
        .where(
      'date',
      isLessThanOrEqualTo: DateService.toStorageDate(endOfMonth),
    )
        .orderBy('date')
        .get();

    return snapshots.docs.map((doc) => Attendance.fromDoc(doc)).toList();
  }

  /// Fetch attendance for a user between startDate and endDate
  Future<List<Attendance>> fetchStartToEndDateAttendanceForUser({
    required DocumentReference userRef,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final snapshots = await _attendanceRef
        .where('user', isEqualTo: userRef)
        .where(
      'date',
      isGreaterThanOrEqualTo: DateService.toStorageDate(startDate),
    )
        .where(
      'date',
      isLessThanOrEqualTo: DateService.toStorageDate(endDate),
    )
        .orderBy('date')
        .get();

    return snapshots.docs.map((doc) => Attendance.fromDoc(doc)).toList();
  }

  /// Fetch attendance for all users between startDate and endDate
  Future<List<Attendance>> fetchAttendanceForMonthAllUsers({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final snapshots = await _attendanceRef
        .where(
      'date',
      isGreaterThanOrEqualTo: DateService.toStorageDate(startDate),
    )
        .where(
      'date',
      isLessThanOrEqualTo: DateService.toStorageDate(endDate),
    )
        .orderBy('date')
        .get();

    return snapshots.docs.map((doc) => Attendance.fromDoc(doc)).toList();
  }
  /// Fetch all attendance for a specific user
  Future<List<Attendance>> fetchAttendanceForUser(String userId) async {
    final userRef = UserModelService.instance.getUserDocRef(userId);
    final snapshots = await _attendanceRef
        .where('user', isEqualTo: userRef)
        .orderBy('date')
        .get();

    return snapshots.docs.map((doc) => Attendance.fromDoc(doc)).toList();
  }

  /// Delete a specific attendance document
  Future<void> deleteAttendance(String attendanceId) async {
    await _attendanceRef.doc(attendanceId).delete();
  }
  /// Batch delete all attendance for a user
  Future<void> deleteAllAttendanceForUser(String userId) async {
    final userRef = UserModelService.instance.getUserDocRef(userId);
    final snapshots = await _attendanceRef
        .where('user', isEqualTo: userRef)
        .get(); // no orderBy, avoids index

    final batch = _firestore.batch();
    for (var doc in snapshots.docs) {
      batch.delete(doc.reference);
    }

    await batch.commit();
  }
}
