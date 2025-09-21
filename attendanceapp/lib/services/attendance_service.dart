import 'user_model_service.dart';
import 'attendance_model_service.dart';
import '../models/user_model.dart';
import '../models/attendance_model.dart';
import 'date_service.dart';

class AttendanceService {

  /// Scan user attendance
  Future<void> scanUser({required UserModel user, required bool isScanIn}) async {
    final userRef = UserModelService.instance.getUserDocRef(user.id);
    final todayStr = DateService.toStorageDate(DateTime.now());

    // Check if an attendance record exists for today
    final existingAttendance = await AttendanceModelService.instance.fetchAttendanceForDate(
      userId: user.id,
      date: todayStr,
    );

    final now = DateTime.now();

    if (existingAttendance == null) {
      if (!isScanIn) {
        throw Exception("❌ ${user.name} cannot scan out without scanning in today");
      }
      // Generate an ID based on date + timestamp
      final id = "${todayStr}-${now.millisecondsSinceEpoch}";

      // Add new attendance
      await AttendanceModelService.instance.addAttendance(
        Attendance(
          id: id,
          userRef: userRef,
          userName: user.name,
          date: todayStr,
          scanIn: now,
          scanOut: null,
        ),
      );
    } else {
      // Update existing attendance
      if (isScanIn) {
        if (existingAttendance.scanIn != null) {
          throw Exception("❌ ${user.name} already scanned in today");
        }
        if (existingAttendance.scanOut != null) {
          throw Exception("❌ ${user.name} cannot scan in after scanning out today");
        }
        existingAttendance.scanIn = now;
      } else {
        if (existingAttendance.scanIn == null) {
          throw Exception("❌ ${user.name} must scan in before scanning out");
        }
        if (existingAttendance.scanOut != null) {
          throw Exception("❌ ${user.name} already scanned out today");
        }
        existingAttendance.scanOut = now;
      }

      await AttendanceModelService.instance.updateAttendance(existingAttendance);
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

    // Use AttendanceModelService to fetch all attendance for the month
    final attendances = await AttendanceModelService.instance.fetchStartToEndDateAttendanceForUser(
      userRef: userRef,
      startDate: startOfMonth,
      endDate: endOfMonth,
    );

    Map<String, Map<String, String>> result = {};

    // Pre-fill all dates with N/A
    for (int i = 1; i <= totalDays; i++) {
      final date = DateTime(month.year, month.month, i);
      result[DateService.toStorageDate(date)] = {'scanIn': 'N/A', 'scanOut': 'N/A'};
    }

    // Fill in actual attendance
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
