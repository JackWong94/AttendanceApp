import 'package:excel/excel.dart';
import 'dart:html' as html;
import '../services/date_service.dart';

class ExportExcelService {
  /// Reusable header creator
  static void createInfoHeader(Sheet sheet, {List<String>? lines}) {
    final yellowStyle = CellStyle(
      backgroundColorHex: "#FFFF00",
      fontFamily: getFontFamily(FontFamily.Arial),
    );

    final infoLines = lines ??
        [
          'Thanks for using Attendance App!',
          'Generated data located at next sheets.',
          'Please download the data and save locally as the data will be deleted each year.'
        ];

    for (int i = 0; i < infoLines.length; i++) {
      final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: i));
      cell.value = infoLines[i];
      cell.cellStyle = yellowStyle;
    }

    // Optional: set column width to make text visible
    sheet.setColWidth(0, 100);
  }

  /// Export single day attendance (all users in 1 sheet)
  static void exportDayAttendance({
    required Map<String, Map<String, String>> attendanceMap,
    required Map<String, String> userNames,
    required DateTime selectedDate,
    String? selectedUserId,
  }) {
    final excel = Excel.createExcel();

    // Reusable header
    createInfoHeader(excel['Sheet1']);

    final sheet = excel['Attendance'];

    sheet.appendRow([
      'User',
      'Normal In',
      'Lunch Out',
      'Lunch In',
      'Normal Out',
      'OT In',
      'OT Out'
    ]);

    final usersToExport = selectedUserId != null ? [selectedUserId] : userNames.keys.toList();
    final dateStr = DateService.toStorageDate(selectedDate);

    for (var uid in usersToExport) {
      final record = attendanceMap[uid]?[dateStr]?.split('|') ??
          ['N/A', 'N/A', 'N/A', 'N/A', 'N/A', 'N/A'];
      sheet.appendRow([
        userNames[uid] ?? uid,
        record[0],
        record[1],
        record[2],
        record[3],
        record[4],
        record[5],
      ]);
    }

    final fileBytes = excel.encode();
    if (fileBytes == null) return;

    final blob = html.Blob([fileBytes]);
    final url = html.Url.createObjectUrlFromBlob(blob);
    final anchor = html.AnchorElement(href: url)
      ..setAttribute(
        'download',
        'attendance-${DateService.toStorageDate(selectedDate)}.xlsx',
      )
      ..click();
    html.Url.revokeObjectUrl(url);
  }

  /// Export monthly attendance
  static void exportMonthAttendance({
    required Map<String, Map<String, String>> attendanceMap,
    required Map<String, String> userNames,
    DateTime? selectedDate,
    String? selectedUserId,
  }) {
    final excel = Excel.createExcel();
    // Reusable header
    createInfoHeader(excel['Sheet1']);
    final usersToExport = selectedUserId != null ? [selectedUserId] : attendanceMap.keys.toList();

    for (var uid in usersToExport) {
      final sheetName = userNames[uid] ?? uid;
      final sheet = excel[sheetName];

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

    final fileBytes = excel.encode();
    if (fileBytes == null) return;

    final blob = html.Blob([fileBytes]);
    final url = html.Url.createObjectUrlFromBlob(blob);
    final anchor = html.AnchorElement(href: url)
      ..setAttribute(
        'download',
        selectedDate != null
            ? 'attendance-${DateService.toMonthString(selectedDate)}.xlsx'
            : 'attendance.xlsx',
      )
      ..click();
    html.Url.revokeObjectUrl(url);
  }
}
