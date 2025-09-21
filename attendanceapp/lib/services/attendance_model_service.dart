import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/attendance_model.dart';
import 'user_model_service.dart';
import 'date_service.dart';
import 'package:attendanceapp/services/attendance_service.dart' show ScanType;
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
  DateTime? getScanInByType(Attendance attendance, ScanType type) {
    switch (type) {
      case ScanType.normal:
        return attendance.scanIn;
      case ScanType.lunch:
        return attendance.scanInLunch;
      case ScanType.ot:
        return attendance.scanInOt;
    }
  }

  DateTime? getScanOutByType(Attendance attendance, ScanType type) {
    switch (type) {
      case ScanType.normal:
        return attendance.scanOut;
      case ScanType.lunch:
        return attendance.scanOutLunch;
      case ScanType.ot:
        return attendance.scanOutOt;
    }
  }

  void setScanInByType(Attendance attendance, ScanType type, DateTime time) {
    switch (type) {
      case ScanType.normal:
        attendance.scanIn = time;
        break;
      case ScanType.lunch:
        attendance.scanInLunch = time;
        break;
      case ScanType.ot:
        attendance.scanInOt = time;
        break;
    }
  }

  void setScanOutByType(Attendance attendance, ScanType type, DateTime time) {
    switch (type) {
      case ScanType.normal:
        attendance.scanOut = time;
        break;
      case ScanType.lunch:
        attendance.scanOutLunch = time;
        break;
      case ScanType.ot:
        attendance.scanOutOt = time;
        break;
    }
  }

  /// Generate ID based on date + increment
  Future<String> generateId(String date) async {
    final snapshot = await _attendanceRef
        .where('date', isEqualTo: date)
        .orderBy(FieldPath.documentId, descending: true)
        .limit(1)
        .get();

    int nextNumber = 1;
    if (snapshot.docs.isNotEmpty) {
      final lastId = snapshot.docs.first.id; // e.g., "2025-09-20_3"
      final parts = lastId.split('_');
      if (parts.length == 2) {
        final lastNum = int.tryParse(parts[1]);
        if (lastNum != null) nextNumber = lastNum + 1;
      }
    }

    return '${date}_$nextNumber';
  }

  /// Add new attendance
  Future<void> addAttendance(Attendance attendance) async {
    final generatedId = await generateId(attendance.date);
    await _attendanceRef.doc(generatedId).set(attendance.toMap());
  }

  /// Update existing attendance
  Future<void> updateAttendance(Attendance attendance) async {
    await _attendanceRef.doc(attendance.id).set(
      attendance.toMap(),
      SetOptions(merge: true),
    );
  }

  /// Fetch attendance for a user for a specific date
  Future<Attendance?> fetchAttendanceForDate({
    required String userId,
    required String date,
  }) async {
    final userRef = UserModelService.instance.getUserDocRef(userId);

    final snapshot = await _attendanceRef
        .where('user', isEqualTo: userRef)
        .where('date', isEqualTo: date)
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) return null;

    return Attendance.fromDoc(snapshot.docs.first);
  }

  /// Fetch all attendance for a user for a month (single query)
  Future<List<Attendance>> fetchMonthlyAttendance({
    required String userId,
    required DateTime month,
  }) async {
    final userRef = UserModelService.instance.getUserDocRef(userId);
    final startOfMonth = DateTime(month.year, month.month, 1);
    final endOfMonth = DateTime(month.year, month.month + 1, 0);

    final snapshots = await _attendanceRef
        .where('user', isEqualTo: userRef)
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
