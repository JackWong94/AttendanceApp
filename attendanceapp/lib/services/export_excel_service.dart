import 'package:excel/excel.dart';
import 'dart:html' as html;
import '../services/date_service.dart';

class ExportExcelService {
  /// Export attendance map to Excel
  /// [attendanceMap] format: {userId: {date: "normalIn|lunchOut|lunchIn|normalOut|otIn|otOut"}}
  /// [userNames] format: {userId: userName}
  /// [selectedUserId] optional: if provided, only export that user
  /// [selectedDate] for naming the file
  /// [isDay] determines whether the export is for a day or a month
  static void exportAttendance({
    required Map<String, Map<String, String>> attendanceMap,
    required Map<String, String> userNames,
    String? selectedUserId,
    required DateTime selectedDate,
    required bool isDay,
  }) {
    final excel = Excel.createExcel();
    excel.delete('Sheet1');

    final usersToExport = selectedUserId != null ? [selectedUserId] : attendanceMap.keys.toList();

    for (var uid in usersToExport) {
      final sheetName = userNames[uid] ?? uid;
      final sheet = excel[sheetName];

      // Header row
      sheet.appendRow([
        'Date',
        'Normal In',
        'Lunch Out',
        'Lunch In',
        'Normal Out',
        'OT In',
        'OT Out'
      ]);

      final days = attendanceMap[uid]?.keys.toList() ?? [];
      for (var day in days) {
        final split = attendanceMap[uid]![day]!.split('|');
        sheet.appendRow([
          day,
          split[0],
          split[1],
          split[2],
          split[3],
          split[4],
          split[5],
        ]);
      }
    }

    // Encode and trigger download
    final fileBytes = excel.encode();
    if (fileBytes == null) return;

    final blob = html.Blob([fileBytes]);
    final url = html.Url.createObjectUrlFromBlob(blob);
    final anchor = html.AnchorElement(href: url)
      ..setAttribute(
        'download',
        isDay
            ? 'attendance-${DateService.toStorageDate(selectedDate)}.xlsx'
            : 'attendance-${DateService.toMonthString(selectedDate)}.xlsx',
      )
      ..click();
    html.Url.revokeObjectUrl(url);
  }
}
