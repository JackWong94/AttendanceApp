import '../models/attendance_model.dart';
import 'attendance_model_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/date_service.dart';

class AttendanceService {
  final AttendanceModelService _modelService = AttendanceModelService.instance;

  /// Generate a deterministic or indexed docId
  Future<String> _generateDocId(String dateKey, String userId) async {
    String baseId = "${dateKey}_$userId";
    String docId = baseId;

    int counter = 1;
    while (true) {
      final exists = await _modelService.attendanceRef.doc(docId).get();

      if (!exists.exists) {
        break; // free ID found
      }
      counter++;
      docId = "${baseId}_$counter";
    }

    return docId;
  }

  /// Add a scan-in
  Future<String> addScanIn({
    required String userId,
    required DateTime time,
    required String url,
  }) async {
    final dateKey = DateService.toStorageDate(time);
    final docId = await _generateDocId(dateKey, userId);

    Attendance? attendance = await _modelService.fetchAttendanceForDate(
      userId: userId,
      date: dateKey,
    );

    attendance ??= Attendance(
      id: docId,
      userRef: FirebaseFirestore.instance.collection("users").doc(userId),
      date: dateKey,
      scanIns: [],
      scanOuts: [],
    );

    if (attendance.scanIns.length >= 3) {
      return "You already have 3 scan-ins today.";
    }

    attendance.scanIns.add(
      ScanRecord(time: time, imageUrl: url),
    );

    await saveAttendance(attendance);
    return "Scan-in recorded successfully (${attendance.scanIns.length}/3).";
  }

  /// Add a scan-out
  Future<String> addScanOut({
    required String userId,
    required DateTime time,
    required String url,
  }) async {
    final dateKey = DateService.toStorageDate(time);
    final docId = await _generateDocId(dateKey, userId);

    Attendance? attendance = await _modelService.fetchAttendanceForDate(
      userId: userId,
      date: dateKey,
    );

    attendance ??= Attendance(
      id: docId,
      userRef: FirebaseFirestore.instance.collection("users").doc(userId),
      date: dateKey,
      scanIns: [],
      scanOuts: [],
    );

    if (attendance.scanOuts.length >= 3) {
      return "You already have 3 scan-outs today.";
    }

    attendance.scanOuts.add(
      ScanRecord(time: time, imageUrl: url),
    );

    await saveAttendance(attendance);
    return "Scan-out recorded successfully (${attendance.scanOuts.length}/3).";
  }

  /// Save attendance
  Future<void> saveAttendance(Attendance attendance) async {
    if (attendance.id.isEmpty) {
      throw Exception("Attendance must have a valid ID before saving");
    }
    await _modelService.setAttendance(attendance);
  }

  /// Get attendance for a specific date
  Future<Attendance?> getAttendanceForDate({
    required String userId,
    required String date,
  }) {
    return _modelService.fetchAttendanceForDate(userId: userId, date: date);
  }

  /// Get all attendance for a user
  Future<List<Attendance>> getAllAttendanceForUser(String userId) async {
    return _modelService.fetchAttendanceForUser(userId);
  }

  /// Delete all attendance for a user
  Future<void> deleteUserAttendance(String userId) async {
    final allAttendance = await getAllAttendanceForUser(userId);

    for (var att in allAttendance) {
      await _modelService.deleteAttendance(att.id);
    }
  }

  /// Get attendance for a month
  Future<List<Attendance>> getMonthlyAttendance({
    required String userId,
    required DateTime month,
  }) {
    return _modelService.fetchMonthlyAttendance(userId: userId, month: month);
  }

  /// Get attendance for all users in a date range
  Future<List<Attendance>> getAttendanceForAllUsers({
    required DateTime startDate,
    required DateTime endDate,
  }) {
    return _modelService.fetchAttendanceForMonthAllUsers(
      startDate: startDate,
      endDate: endDate,
    );
  }
}
