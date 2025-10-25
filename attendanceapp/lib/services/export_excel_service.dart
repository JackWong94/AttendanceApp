import 'dart:typed_data';
import 'dart:html' as html;
import 'package:syncfusion_flutter_xlsio/xlsio.dart';
import '../services/date_service.dart';

// Define attendance columns as enum at top-level
enum AttendanceColumn {
  user,
  scanIn1,
  scanOut1,
  scanIn2,
  scanOut2,
  scanIn3,
  scanOut3,
  lunch,
  ot,
  ut,
  status
}

// Helper to get column index (1-based for Excel)
int colIndex(AttendanceColumn col) => col.index + 1;

class ExportExcelService {
  static Workbook _createWorkbook() => Workbook();

  // Row constants
  static const int infoHeaderRow = 1;
  static const int headerRow = 2;
  static const int firstDataRow = 3;

  static void createInfoHeader(Worksheet sheet, String title) {
    final cell = sheet.getRangeByIndex(infoHeaderRow, colIndex(AttendanceColumn.user));
    cell.setText(title);
    cell.cellStyle.bold = true;
    cell.cellStyle.hAlign = HAlignType.left;
    cell.cellStyle.vAlign = VAlignType.center;
  }

  static void addHeaderRow(Worksheet sheet, List<String> headers, int rowIndex) {
    for (int i = 0; i < headers.length; i++) {
      final cell = sheet.getRangeByIndex(rowIndex, i + 1);
      cell.setText(headers[i]);
      cell.cellStyle.bold = true;
      cell.cellStyle.backColor = '#D9E1F2';
      cell.cellStyle.hAlign = HAlignType.center;
      cell.cellStyle.vAlign = VAlignType.center;
      cell.cellStyle.borders.all.lineStyle = LineStyle.thin;
    }
  }

  static void appendRow(
      Worksheet sheet,
      int rowIndex,
      List<dynamic> values, {
        bool alternate = false,
        bool isSunday = false,
      }) {
    final bgColor = isSunday ? '#FFA500' : (alternate ? '#F2F2F2' : '#FFFFFF');

    for (int i = 0; i < values.length; i++) {
      final cell = sheet.getRangeByIndex(rowIndex, i + 1);
      final val = values[i];

      if (val is String && val.contains(':')) {
        try {
          final parts = val.split(':');
          if (parts.length == 2) {
            final dt = DateTime(0, 1, 1, int.parse(parts[0]), int.parse(parts[1]));
            cell.setDateTime(dt);
            cell.numberFormat = 'hh:mm';
          } else {
            cell.setText(val);
          }
        } catch (_) {
          cell.setText(val);
        }
      } else if (val is String && val.toUpperCase() == 'N/A') {
        cell.setText('');
      } else {
        cell.setText(val.toString());
      }

      cell.cellStyle.backColor = bgColor;
      cell.cellStyle.hAlign = HAlignType.left;
      cell.cellStyle.vAlign = VAlignType.center;
      cell.cellStyle.borders.all.lineStyle = LineStyle.thin;
    }
  }

  static void setColumnWidths(Worksheet sheet, List<double> widths) {
    for (int i = 0; i < widths.length; i++) {
      final range = sheet.getRangeByIndex(1, i + 1);
      range.columnWidth = widths[i];
    }
  }

  static void addLegend(Worksheet sheet, int startRow) {
    // Add legend section below the table
    final titleCell = sheet.getRangeByIndex(startRow, 1);
    titleCell.setText('Legend:');
    titleCell.cellStyle.bold = true;
    titleCell.cellStyle.hAlign = HAlignType.left;
    titleCell.cellStyle.vAlign = VAlignType.center;

    // Orange = Sunday
    final cellColor = sheet.getRangeByIndex(startRow + 1, 1);
    cellColor.cellStyle.backColor = '#FFA500';
    cellColor.setText('(Orange)');

    final cellText = sheet.getRangeByIndex(startRow + 1, 2);
    cellText.setText('Sunday');

    sheet.getRangeByIndex(startRow + 1, 1, startRow + 1, 2).cellStyle.borders.all.lineStyle =
        LineStyle.thin;
  }

  /// === Status formula helper (dynamic, works for both day & month) ===
  /// → Checks if any scan-in/out cell contains a valid time (“:”)
  /// → Returns "Present" if found, otherwise "Absent"
  static String statusFormula(int rowNum) {
    final scanStart = colIndex(AttendanceColumn.scanIn1);
    final scanEnd = colIndex(AttendanceColumn.scanOut3);

    final conditions = <String>[];
    for (int col = scanStart; col <= scanEnd; col++) {
      final colLetter = _excelColLetter(col);
      conditions.add('AND(ISTEXT($colLetter$rowNum), ISNUMBER(FIND(":", $colLetter$rowNum)))');
    }

    return '=IF(OR(${conditions.join(',')}),"Present","Absent")';
  }

  // === Day Attendance Export ===
  static void exportDayAttendance({
    required Map<String, Map<String, String>> attendanceMap,
    required Map<String, String> userNames,
    required DateTime selectedDate,
    String? selectedUserId,
  }) {
    final workbook = _createWorkbook();
    final sheet = workbook.worksheets[0];
    sheet.name = 'Attendance';

    createInfoHeader(sheet, 'Attendance on ${DateService.toStorageDate(selectedDate)}');

    // Column headers for daily report
    final headers = [
      'User',
      'Scan In 1', 'Scan Out 1',
      'Scan In 2', 'Scan Out 2',
      'Scan In 3', 'Scan Out 3',
      'Lunch (h)',
      'OT (h)',
      'UT (h)',
      'Status',
    ];
    addHeaderRow(sheet, headers, headerRow);
    setColumnWidths(sheet, [25, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12]);

    final usersToExport = selectedUserId != null ? [selectedUserId] : userNames.keys.toList();

    for (int i = 0; i < usersToExport.length; i++) {
      final uid = usersToExport[i];
      final dateStr = DateService.toStorageDate(selectedDate);
      final record = attendanceMap[uid]?[dateStr]?.split('|') ?? List.filled(6, '');
      appendRow(sheet, firstDataRow + i, [userNames[uid] ?? uid, ...record],
          alternate: i % 2 != 0,
          isSunday: selectedDate.weekday == DateTime.sunday);

      final rowNum = firstDataRow + i;

      // 🧮 Formula for Lunch (h): =(D - C) * 24 hours
      sheet.getRangeByIndex(rowNum, colIndex(AttendanceColumn.lunch))
        ..formula = '=(D$rowNum-C$rowNum)*24'
        ..numberFormat = '0.00'
        ..cellStyle.borders.all.lineStyle = LineStyle.thin;

      // 🧮 Formula for OT (h): Compare scan times with 5 PM (17:00)
      //    Checks Scan Out 3 → Scan Out 2 → Scan Out 1, whichever exists first
      sheet.getRangeByIndex(rowNum, colIndex(AttendanceColumn.ot))
        ..formula =
            '=IF(G$rowNum<>"",(G$rowNum-TIME(17,0,0))*24,IF(E$rowNum<>"",(E$rowNum-TIME(17,0,0))*24,IF(C$rowNum<>"",(C$rowNum-TIME(17,0,0))*24,0)))'
        ..numberFormat = '0.00'
        ..cellStyle.borders.all.lineStyle = LineStyle.thin;

      // 🧮 Formula for UT (h): Compare scan times with 5 PM (17:00)
      //    Checks Scan Out 3 → Scan Out 2 → Scan Out 1, whichever exists first
      sheet.getRangeByIndex(rowNum, colIndex(AttendanceColumn.ut))
        ..formula =
            '=IF(G$rowNum<>"",(G$rowNum-TIME(17,0,0))*24,IF(E$rowNum<>"",(E$rowNum-TIME(17,0,0))*24,IF(C$rowNum<>"",(C$rowNum-TIME(17,0,0))*24,0)))'
        ..numberFormat = '0.00'
        ..cellStyle.borders.all.lineStyle = LineStyle.thin;

      // ✅ Status = Present / Absent based on any valid scan
      sheet.getRangeByIndex(rowNum, colIndex(AttendanceColumn.status))
        ..formula = statusFormula(rowNum)
        ..cellStyle.borders.all.lineStyle = LineStyle.thin;
    }

    // 🧾 Add total row (sum of lunch/OT, count of Present)
    final totalRow = firstDataRow + usersToExport.length;
    sheet.getRangeByIndex(totalRow, colIndex(AttendanceColumn.scanOut3)).setText('Total');
    sheet.getRangeByIndex(totalRow, colIndex(AttendanceColumn.scanOut3)).cellStyle.bold = true;
    sheet.getRangeByIndex(totalRow, colIndex(AttendanceColumn.scanOut3))
        .cellStyle.borders.all.lineStyle = LineStyle.thin;

    // 🧮 SUM of all Lunch hours
    sheet.getRangeByIndex(totalRow, colIndex(AttendanceColumn.lunch)).formula =
    'SUM(${_excelColLetter(colIndex(AttendanceColumn.lunch))}$firstDataRow:${_excelColLetter(colIndex(AttendanceColumn.lunch))}${totalRow - 1})';
    sheet.getRangeByIndex(totalRow, colIndex(AttendanceColumn.lunch))
      ..numberFormat = '0.00'
      ..cellStyle.borders.all.lineStyle = LineStyle.thin;

    // 🧮 SUM of all OT hours
    sheet.getRangeByIndex(totalRow, colIndex(AttendanceColumn.ot)).formula =
    'SUMPRODUCT(--(${_excelColLetter(colIndex(AttendanceColumn.ot))}$firstDataRow:${_excelColLetter(colIndex(AttendanceColumn.ot))}${totalRow - 1}>0),${_excelColLetter(colIndex(AttendanceColumn.ot))}$firstDataRow:${_excelColLetter(colIndex(AttendanceColumn.ot))}${totalRow - 1})';
    sheet.getRangeByIndex(totalRow, colIndex(AttendanceColumn.ot))
      ..numberFormat = '0.00'
      ..cellStyle.borders.all.lineStyle = LineStyle.thin;

    // 🧮 SUM of all UT (negative) hours
    sheet.getRangeByIndex(totalRow, colIndex(AttendanceColumn.ut)).formula =
    'SUMPRODUCT(--(${_excelColLetter(colIndex(AttendanceColumn.ut))}$firstDataRow:${_excelColLetter(colIndex(AttendanceColumn.ut))}${totalRow - 1}<0),${_excelColLetter(colIndex(AttendanceColumn.ut))}$firstDataRow:${_excelColLetter(colIndex(AttendanceColumn.ut))}${totalRow - 1})';
    sheet.getRangeByIndex(totalRow, colIndex(AttendanceColumn.ut))
      ..numberFormat = '0.00'
      ..cellStyle.borders.all.lineStyle = LineStyle.thin;

    // 🧮 COUNT how many users are "Present"
    final statusColLetter = _excelColLetter(colIndex(AttendanceColumn.status));
    sheet.getRangeByIndex(totalRow, colIndex(AttendanceColumn.status))
      ..formula =
          'COUNTIF($statusColLetter${firstDataRow}:$statusColLetter${totalRow - 1},"Present")'
      ..cellStyle.bold = true
      ..cellStyle.borders.all.lineStyle = LineStyle.thin;

    addLegend(sheet, totalRow + 2);
    _saveExcelFile(workbook, 'attendance-${DateService.toStorageDate(selectedDate)}.xlsx');
  }

  // === Month Attendance Export ===
  static void exportMonthAttendance({
    required Map<String, Map<String, String>> attendanceMap,
    required Map<String, String> userNames,
    DateTime? selectedDate,
    String? selectedUserId,
  }) {
    final workbook = _createWorkbook();
    final defaultSheet = workbook.worksheets[0];

    final usersToExport = selectedUserId != null ? [selectedUserId] : attendanceMap.keys.toList();

    for (var i = 0; i < usersToExport.length; i++) {
      final uid = usersToExport[i];
      final sheetName = userNames[uid] ?? uid;

      Worksheet sheet;
      if (i == 0) {
        sheet = defaultSheet;
        sheet.name = sheetName;
      } else {
        sheet = workbook.worksheets.addWithName(sheetName);
      }

      final monthStr = selectedDate != null ? DateService.toMonthString(selectedDate) : '';
      createInfoHeader(sheet, '$sheetName Attendance for $monthStr');

      // Column headers for monthly report
      final headers = [
        'Date',
        'Scan In 1', 'Scan Out 1',
        'Scan In 2', 'Scan Out 2',
        'Scan In 3', 'Scan Out 3',
        'Lunch (h)',
        'OT (h)',
        'UT (h)',
        'Status',
      ];
      addHeaderRow(sheet, headers, headerRow);
      setColumnWidths(sheet, [12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12]);

      final days = attendanceMap[uid]?.keys.toList() ?? [];
      for (int j = 0; j < days.length; j++) {
        final dayStr = days[j];
        final dt = DateTime.parse(dayStr);
        final record = attendanceMap[uid]?[dayStr]?.split('|') ?? List.filled(6, '');
        appendRow(sheet, firstDataRow + j, [dayStr, ...record],
            isSunday: dt.weekday == DateTime.sunday,
            alternate: j % 2 != 0);

        final rowNum = firstDataRow + j;

        // 🧮 Formula for Lunch (h): =(D - C) * 24 hours
        sheet.getRangeByIndex(rowNum, colIndex(AttendanceColumn.lunch))
          ..formula = '=(D$rowNum-C$rowNum)*24'
          ..numberFormat = '0.00'
          ..cellStyle.borders.all.lineStyle = LineStyle.thin;

        // 🧮 Formula for OT (h): same logic as daily (based on 17:00)
        sheet.getRangeByIndex(rowNum, colIndex(AttendanceColumn.ot))
          ..formula =
              '=IF(G$rowNum<>"",(G$rowNum-TIME(17,0,0))*24,IF(E$rowNum<>"",(E$rowNum-TIME(17,0,0))*24,IF(C$rowNum<>"",(C$rowNum-TIME(17,0,0))*24,0)))'
          ..numberFormat = '0.00'
          ..cellStyle.borders.all.lineStyle = LineStyle.thin;

        // 🧮 Formula for UT (h): same logic as daily (based on 17:00)
        sheet.getRangeByIndex(rowNum, colIndex(AttendanceColumn.ut))
          ..formula =
              '=IF(G$rowNum<>"",(G$rowNum-TIME(17,0,0))*24,IF(E$rowNum<>"",(E$rowNum-TIME(17,0,0))*24,IF(C$rowNum<>"",(C$rowNum-TIME(17,0,0))*24,0)))'
          ..numberFormat = '0.00'
          ..cellStyle.borders.all.lineStyle = LineStyle.thin;

        // ✅ Status (Present/Absent)
        sheet.getRangeByIndex(rowNum, colIndex(AttendanceColumn.status))
          ..formula = statusFormula(rowNum)
          ..cellStyle.borders.all.lineStyle = LineStyle.thin;
      }

      // 🧾 Add totals for monthly sheet
      final totalRow = firstDataRow + days.length;
      sheet.getRangeByIndex(totalRow, colIndex(AttendanceColumn.scanOut3)).setText('Total');
      sheet.getRangeByIndex(totalRow, colIndex(AttendanceColumn.scanOut3)).cellStyle.bold = true;
      sheet.getRangeByIndex(totalRow, colIndex(AttendanceColumn.scanOut3))
          .cellStyle.borders.all.lineStyle = LineStyle.thin;

      // 🧮 SUM of all Lunch hours
      sheet.getRangeByIndex(totalRow, colIndex(AttendanceColumn.lunch)).formula =
      'SUM(${_excelColLetter(colIndex(AttendanceColumn.lunch))}$firstDataRow:${_excelColLetter(colIndex(AttendanceColumn.lunch))}${totalRow - 1})';
      sheet.getRangeByIndex(totalRow, colIndex(AttendanceColumn.lunch))
        ..numberFormat = '0.00'
        ..cellStyle.borders.all.lineStyle = LineStyle.thin;

      // 🧮 SUM of all OT hours
      sheet.getRangeByIndex(totalRow, colIndex(AttendanceColumn.ot)).formula =
      'SUMPRODUCT(--(${_excelColLetter(colIndex(AttendanceColumn.ot))}$firstDataRow:${_excelColLetter(colIndex(AttendanceColumn.ot))}${totalRow - 1}>0),${_excelColLetter(colIndex(AttendanceColumn.ot))}$firstDataRow:${_excelColLetter(colIndex(AttendanceColumn.ot))}${totalRow - 1})';
      sheet.getRangeByIndex(totalRow, colIndex(AttendanceColumn.ot))
        ..numberFormat = '0.00'
        ..cellStyle.borders.all.lineStyle = LineStyle.thin;

      // 🧮 SUM of all UT (negative) hours
      sheet.getRangeByIndex(totalRow, colIndex(AttendanceColumn.ut)).formula =
      'SUMPRODUCT(--(${_excelColLetter(colIndex(AttendanceColumn.ut))}$firstDataRow:${_excelColLetter(colIndex(AttendanceColumn.ut))}${totalRow - 1}<0),${_excelColLetter(colIndex(AttendanceColumn.ut))}$firstDataRow:${_excelColLetter(colIndex(AttendanceColumn.ut))}${totalRow - 1})';
      sheet.getRangeByIndex(totalRow, colIndex(AttendanceColumn.ut))
        ..numberFormat = '0.00'
        ..cellStyle.borders.all.lineStyle = LineStyle.thin;

      // 🧮 COUNT Present days for that user
      final statusColLetter = _excelColLetter(colIndex(AttendanceColumn.status));
      sheet.getRangeByIndex(totalRow, colIndex(AttendanceColumn.status))
        ..formula =
            'COUNTIF($statusColLetter${firstDataRow}:$statusColLetter${totalRow - 1},"Present")'
        ..cellStyle.bold = true
        ..cellStyle.borders.all.lineStyle = LineStyle.thin;

      addLegend(sheet, totalRow + 2);
    }

    final fileName = selectedDate != null
        ? 'attendance-${DateService.toMonthString(selectedDate)}.xlsx'
        : 'attendance.xlsx';

    _saveExcelFile(workbook, fileName);
  }

  /// Helper to convert column index to Excel letter (e.g., 1 → A, 27 → AA)
  static String _excelColLetter(int colIndex) {
    var dividend = colIndex;
    var colLetter = '';
    while (dividend > 0) {
      var modulo = (dividend - 1) % 26;
      colLetter = String.fromCharCode(65 + modulo) + colLetter;
      dividend = ((dividend - modulo) / 26).floor();
    }
    return colLetter;
  }

  // Save file to browser (Web)
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
