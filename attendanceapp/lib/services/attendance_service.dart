import 'user_model_service.dart';
import 'attendance_model_service.dart';
import '../models/user_model.dart';
import '../models/attendance_model.dart';
import 'date_service.dart';
import 'package:attendanceapp/services/attendance_service.dart' show ScanType;

/// Result object for scanning
class ScanResult {
  final bool success;
  final String message;

  ScanResult({required this.success, required this.message});
}
enum ScanType { normal, lunch, ot }
class AttendanceService {
  /// Scan user attendance (prevent repeated scan-in or scan-out)
  Future<ScanResult> scanUser({
    required UserModel user,
    required bool isScanIn,
    required ScanType scanType,
  }) async {
    final userRef = UserModelService.instance.getUserDocRef(user.id);
    final todayStr = DateService.toStorageDate(DateTime.now());
    final now = DateTime.now();

    final existingAttendance = await AttendanceModelService.instance.fetchAttendanceForDate(
      userId: user.id,
      date: todayStr,
    );

    if (existingAttendance == null) {
      // No attendance yet
      final newAttendance = Attendance(
        id: "${todayStr}-${now.millisecondsSinceEpoch}",
        userRef: userRef,
        userName: user.name,
        date: todayStr,
      );

      if (isScanIn) {
        AttendanceModelService.instance.setScanInByType(newAttendance, scanType, now);
        await AttendanceModelService.instance.addAttendance(newAttendance);
        return ScanResult(
          success: true,
          message: "✅ ${user.name} scanned in (${scanType.name}) successfully",
        );
      } else {
        AttendanceModelService.instance.setScanOutByType(newAttendance, scanType, now);
        await AttendanceModelService.instance.addAttendance(newAttendance);
        return ScanResult(
          success: true,
          message: "✅ ${user.name} scanned out (${scanType.name}) successfully",
        );
      }
    } else {
      // Attendance exists
      if (isScanIn) {
        if (AttendanceModelService.instance.getScanInByType(existingAttendance, scanType) != null) {
          return ScanResult(
            success: false,
            message: "✖ ${user.name} already scanned in for ${scanType.name} today",
          );
        }
        AttendanceModelService.instance.setScanInByType(existingAttendance, scanType, now);
        await AttendanceModelService.instance.updateAttendance(existingAttendance);
        return ScanResult(
          success: true,
          message: "✅ ${user.name} scanned in (${scanType.name}) successfully",
        );
      } else {
        if (AttendanceModelService.instance.getScanOutByType(existingAttendance, scanType) != null) {
          return ScanResult(
            success: false,
            message: "✖ ${user.name} already scanned out for ${scanType.name} today",
          );
        }
        AttendanceModelService.instance.setScanOutByType(existingAttendance, scanType, now);
        await AttendanceModelService.instance.updateAttendance(existingAttendance);
        return ScanResult(
          success: true,
          message: "✅ ${user.name} scanned out (${scanType.name}) successfully",
        );
      }
    }
  }

  /// Fetch attendance for a single day
  Future<Map<String, String>> fetchAttendance({
    required UserModel user,
    required String date,
  }) async {
    final attendance = await AttendanceModelService.instance.fetchAttendanceForDate(
      userId: user.id,
      date: date,
    );

    if (attendance == null) return {'scanIn': 'N/A', 'scanOut': 'N/A'};

    final scanIn = attendance.scanIn != null
        ? DateService.toDisplayTime(attendance.scanIn!)
        : 'N/A';
    final scanOut = attendance.scanOut != null
        ? DateService.toDisplayTime(attendance.scanOut!)
        : 'N/A';

    return {'scanIn': scanIn, 'scanOut': scanOut};
  }

  /// Fetch attendance for a whole month
  Future<Map<String, Map<String, String>>> fetchMonthlyAttendance({
    required UserModel user,
    required DateTime month,
  }) async {
    final userRef = UserModelService.instance.getUserDocRef(user.id);
    final int totalDays = DateService.getDaysInMonth(month.year, month.month);
    final startOfMonth = DateTime(month.year, month.month, 1);
    final endOfMonth = DateTime(month.year, month.month, totalDays);

    final attendances = await AttendanceModelService.instance.fetchStartToEndDateAttendanceForUser(
      userRef: userRef,
      startDate: startOfMonth,
      endDate: endOfMonth,
    );

    Map<String, Map<String, String>> result = {};

    for (int i = 1; i <= totalDays; i++) {
      final date = DateTime(month.year, month.month, i);
      result[DateService.toStorageDate(date)] = {'scanIn': 'N/A', 'scanOut': 'N/A'};
    }

    for (var attendance in attendances) {
      final dateStr = attendance.date;
      final scanIn = attendance.scanIn != null
          ? DateService.toDisplayTime(attendance.scanIn!)
          : 'N/A';
      final scanOut = attendance.scanOut != null
          ? DateService.toDisplayTime(attendance.scanOut!)
          : 'N/A';

      result[dateStr] = {'scanIn': scanIn, 'scanOut': scanOut};
    }

    return result;
  }
}
