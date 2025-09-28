import 'dart:typed_data';
import 'dart:html' as html;
import 'package:syncfusion_flutter_xlsio/xlsio.dart';
import '../services/date_service.dart';

class ExportExcelService {
  /// Create workbook
  static Workbook _createWorkbook() => Workbook();

  /// Info header (yellow)
  static void createInfoHeader(Worksheet sheet, {List<String>? lines}) {
    final infoLines = lines ?? [
      'Thanks for using Attendance App!',
      'Generated data located at next sheets.',
      'Please download the data and save locally as the data will be deleted each year.'
    ];

    for (int i = 0; i < infoLines.length; i++) {
      final cell = sheet.getRangeByIndex(i + 1, 1);
      cell.setText(infoLines[i]);
      cell.cellStyle.backColor = '#FFFF00';
      cell.cellStyle.bold = true;
      cell.cellStyle.hAlign = HAlignType.center;
      cell.cellStyle.vAlign = VAlignType.center;
    }
  }

  /// Header row style (bold, blue)
  static void addHeaderRow(Worksheet sheet, List<String> headers) {
    for (int i = 0; i < headers.length; i++) {
      final cell = sheet.getRangeByIndex(1, i + 1);
      cell.setText(headers[i]);
      cell.cellStyle.bold = true;
      cell.cellStyle.backColor = '#D9E1F2';
      cell.cellStyle.hAlign = HAlignType.center;
      cell.cellStyle.vAlign = VAlignType.center;
      cell.cellStyle.borders.all.lineStyle = LineStyle.thin;
    }
  }

  /// Append data row
  static void appendRow(Worksheet sheet, int rowIndex, List<dynamic> values, {bool alternate = false}) {
    for (int i = 0; i < values.length; i++) {
      final cell = sheet.getRangeByIndex(rowIndex, i + 1);
      final val = values[i];
      cell.setText((val is String && val.toUpperCase() == 'N/A') ? '' : val.toString());
      cell.cellStyle.backColor = alternate ? '#F2F2F2' : '#FFFFFF';
      cell.cellStyle.borders.all.lineStyle = LineStyle.thin;
      cell.cellStyle.hAlign = HAlignType.left;
      cell.cellStyle.vAlign = VAlignType.center;
    }
  }

  /// Set column widths
  static void setColumnWidths(Worksheet sheet, List<double> widths) {
    for (int i = 0; i < widths.length; i++) {
      // In Syncfusion, columns are 1-based
      final range = sheet.getRangeByIndex(1, i + 1);
      range.columnWidth = widths[i];
    }
  }

  /// Export day attendance
  static void exportDayAttendance({
    required Map<String, Map<String, String>> attendanceMap,
    required Map<String, String> userNames,
    required DateTime selectedDate,
    String? selectedUserId,
  }) {
    final workbook = _createWorkbook();
    final sheet = workbook.worksheets[0];
    sheet.name = 'Attendance';

    createInfoHeader(sheet);
    addHeaderRow(sheet, ['User', 'Scan In 1', 'Scan In 2', 'Scan In 3', 'Scan Out 1', 'Scan Out 2', 'Scan Out 3']);
    setColumnWidths(sheet, [25, 15, 15, 15, 15, 15, 15]);

    final usersToExport = selectedUserId != null ? [selectedUserId] : userNames.keys.toList();
    final dateStr = DateService.toStorageDate(selectedDate);

    for (int i = 0; i < usersToExport.length; i++) {
      final uid = usersToExport[i];
      final record = attendanceMap[uid]?[dateStr]?.split('|') ?? List.filled(6, '');
      appendRow(sheet, i + 2, [userNames[uid] ?? uid, ...record], alternate: i % 2 != 0);
    }

    _saveExcelFile(workbook, 'attendance-${DateService.toStorageDate(selectedDate)}.xlsx');
  }

  /// Export month attendance
  static void exportMonthAttendance({
    required Map<String, Map<String, String>> attendanceMap,
    required Map<String, String> userNames,
    DateTime? selectedDate,
    String? selectedUserId,
  }) {
    final workbook = _createWorkbook();
    final usersToExport = selectedUserId != null ? [selectedUserId] : attendanceMap.keys.toList();

    for (var uid in usersToExport) {
      final sheetName = userNames[uid] ?? uid;
      final sheet = workbook.worksheets.addWithName(sheetName);

      createInfoHeader(sheet);
      addHeaderRow(sheet, ['Date', 'Scan In 1', 'Scan In 2', 'Scan In 3', 'Scan Out 1', 'Scan Out 2', 'Scan Out 3']);
      setColumnWidths(sheet, [20, 15, 15, 15, 15, 15, 15]);

      final days = attendanceMap[uid]?.keys.toList() ?? [];
      for (int i = 0; i < days.length; i++) {
        final day = days[i];
        final record = attendanceMap[uid]?[day]?.split('|') ?? List.filled(6, '');
        appendRow(sheet, i + 2, [day, ...record], alternate: i % 2 != 0);
      }
    }

    final fileName = selectedDate != null
        ? 'attendance-${DateService.toMonthString(selectedDate)}.xlsx'
        : 'attendance.xlsx';

    _saveExcelFile(workbook, fileName);
  }

  /// Save Excel file in browser
  static void _saveExcelFile(Workbook workbook, String fileName) {
    final List<int> bytes = workbook.saveAsStream();
    workbook.dispose();

    final blob = html.Blob([Uint8List.fromList(bytes)]);
    final url = html.Url.createObjectUrlFromBlob(blob);
    final anchor = html.AnchorElement(href: url)
      ..setAttribute('download', fileName)
      ..click();
    html.Url.revokeObjectUrl(url);
  }
}
