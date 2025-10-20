import '../models/attendance_model.dart';
import 'user_model_service.dart';
import 'attendance_model_service.dart';
import '../services/date_service.dart';

class AttendanceService {
  final AttendanceModelService _modelService = AttendanceModelService.instance;

  /// Generate a deterministic docId for a user on a specific date
  String _generateDocId(String dateKey, String userId) {
    // One document per user per day
    return "${dateKey}_$userId";
  }

  /// Add a scan-in
  Future<String> addScanIn({
    required String userId,
    required DateTime time,
    required String url,
  }) async {
    final dateKey = DateService.toStorageDate(time);
    final docId = _generateDocId(dateKey, userId);

    Attendance? attendance = await _modelService.fetchAttendanceForDate(
      userId: userId,
      date: dateKey,
    );

    attendance ??= Attendance(
      id: docId,
      userRef: UserModelService.instance.getUserDocRef(userId), // ✅ tenant-aware
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
    final docId = _generateDocId(dateKey, userId);

    Attendance? attendance = await _modelService.fetchAttendanceForDate(
      userId: userId,
      date: dateKey,
    );

    attendance ??= Attendance(
      id: docId,
      userRef: UserModelService.instance.getUserDocRef(userId), // ✅ tenant-aware
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
