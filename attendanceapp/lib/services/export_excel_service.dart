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

    final infoLines = lines ?? [
      'Thanks for using Attendance App!',
      'Generated data located at next sheets.',
      'Please download the data and save locally as the data will be deleted each year.'
    ];

    for (int i = 0; i < infoLines.length; i++) {
      final cell = sheet.cell(
        CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: i),
      );
      cell.value = infoLines[i];
      cell.cellStyle = yellowStyle;
    }

    sheet.setColWidth(0, 100);
  }

  /// Bold header style
  static CellStyle headerStyle() {
    return CellStyle(
      bold: true,
      fontFamily: getFontFamily(FontFamily.Arial),
      horizontalAlign: HorizontalAlign.Center,
      verticalAlign: VerticalAlign.Center,
      backgroundColorHex: "#D9E1F2", // light blue header
    );
  }

  /// Append a row with optional bold style
  static void appendRow(Sheet sheet, List<dynamic> values, {bool bold = false}) {
    final rowIndex = sheet.maxRows;
    for (var col = 0; col < values.length; col++) {
      final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: rowIndex));
      cell.value = values[col];
      if (bold) {
        cell.cellStyle = headerStyle();
      }
    }
  }

  /// Prepare a sheet with headers and column widths
  static Sheet prepareSheet(
      Excel excel,
      String sheetName,
      List<String> headers, {
        Map<int, double>? columnWidths,
      }) {
    final sheet = excel[sheetName];
    appendRow(sheet, headers, bold: true);

    if (columnWidths != null) {
      columnWidths.forEach((index, width) {
        sheet.setColWidth(index, width);
      });
    }

    return sheet;
  }

  /// Export single day attendance
  static void exportDayAttendance({
    required Map<String, Map<String, String>> attendanceMap,
    required Map<String, String> userNames,
    required DateTime selectedDate,
    String? selectedUserId,
  }) {
    final excel = Excel.createExcel();
    createInfoHeader(excel['Sheet1']);

    final sheet = prepareSheet(
      excel,
      'Attendance',
      ['User', 'Scan In 1', 'Scan In 2', 'Scan In 3', 'Scan Out 1', 'Scan Out 2', 'Scan Out 3'],
      columnWidths: {0: 20, 1: 15, 2: 15, 3: 15, 4: 15, 5: 15, 6: 15},
    );

    final usersToExport = selectedUserId != null ? [selectedUserId] : userNames.keys.toList();
    final dateStr = DateService.toStorageDate(selectedDate);

    for (var uid in usersToExport) {
      final record = attendanceMap[uid]?[dateStr]?.split('|') ?? List.filled(6, '');
      appendRow(sheet, [userNames[uid] ?? uid, ...record]);
    }

    _saveExcelFile(excel, 'attendance-${DateService.toStorageDate(selectedDate)}.xlsx');
  }

  /// Export monthly attendance
  static void exportMonthAttendance({
    required Map<String, Map<String, String>> attendanceMap,
    required Map<String, String> userNames,
    DateTime? selectedDate,
    String? selectedUserId,
  }) {
    final excel = Excel.createExcel();
    createInfoHeader(excel['Sheet1']);

    final usersToExport = selectedUserId != null ? [selectedUserId] : attendanceMap.keys.toList();

    for (var uid in usersToExport) {
      final sheetName = userNames[uid] ?? uid;

      final sheet = prepareSheet(
        excel,
        sheetName,
        ['Date', 'Scan In 1', 'Scan In 2', 'Scan In 3', 'Scan Out 1', 'Scan Out 2', 'Scan Out 3'],
        columnWidths: {0: 20, 1: 15, 2: 15, 3: 15, 4: 15, 5: 15, 6: 15},
      );

      final days = attendanceMap[uid]?.keys.toList() ?? [];
      for (var day in days) {
        final record = attendanceMap[uid]?[day]?.split('|') ?? List.filled(6, '');
        appendRow(sheet, [day, ...record]);
      }
    }

    final fileName = selectedDate != null
        ? 'attendance-${DateService.toMonthString(selectedDate)}.xlsx'
        : 'attendance.xlsx';

    _saveExcelFile(excel, fileName);
  }

  /// Save Excel file in browser
  static void _saveExcelFile(Excel excel, String fileName) {
    final fileBytes = excel.encode();
    if (fileBytes == null) return;

    final blob = html.Blob([fileBytes]);
    final url = html.Url.createObjectUrlFromBlob(blob);
    final anchor = html.AnchorElement(href: url)
      ..setAttribute('download', fileName)
      ..click();
    html.Url.revokeObjectUrl(url);
  }
}
