import '../models/attendance_model.dart';
import 'attendance_model_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/date_service.dart';

class AttendanceService {
  final AttendanceModelService _modelService = AttendanceModelService.instance;

  /// Add a scan-in
  Future<String> addScanIn({
    required String userId,
    required DateTime time,
    required String url,
  }) async {
    final dateKey = DateService.toStorageDate(time);
    final docId = "${userId}_$dateKey"; // unique ID per user per day

    Attendance? attendance = await _modelService.fetchAttendanceForDate(
      userId: userId,
      date: dateKey,
    );

    // Create new if not exist
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
    final docId = "${userId}_$dateKey";

    Attendance? attendance = await _modelService.fetchAttendanceForDate(
      userId: userId,
      date: dateKey,
    );

    // Create new if not exist
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

  /// Get scan-in by index
  DateTime? getScanIn(Attendance attendance, int index) {
    return attendance.scanIns.length > index ? attendance.scanIns[index].time : null;
  }

  /// Get scan-out by index
  DateTime? getScanOut(Attendance attendance, int index) {
    return attendance.scanOuts.length > index ? attendance.scanOuts[index].time : null;
  }

  /// Save attendance (new or existing)
  Future<void> saveAttendance(Attendance attendance) async {
    if (attendance.id.isEmpty) {
      throw Exception("Attendance must have a valid ID before saving");
    }
    // Always update using deterministic ID
    await _modelService.setAttendance(attendance);
  }

  /// Get attendance for a specific date
  Future<Attendance?> getAttendanceForDate({
    required String userId,
    required String date,
  }) {
    return _modelService.fetchAttendanceForDate(userId: userId, date: date);
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
