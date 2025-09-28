import 'dart:typed_data';
import 'dart:html' as html;
import 'package:syncfusion_flutter_xlsio/xlsio.dart';
import '../services/date_service.dart';

class ExportExcelService {
  static Workbook _createWorkbook() => Workbook();

  static void createInfoHeader(Worksheet sheet, String title) {
    final cell = sheet.getRangeByIndex(1, 1);
    cell.setText(title);
    cell.cellStyle.bold = true;
    cell.cellStyle.hAlign = HAlignType.left; // allow overflow
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
    final cellColor = sheet.getRangeByIndex(startRow, 1);
    cellColor.cellStyle.backColor = '#FFA500';
    cellColor.setText('(Orange)');

    final cellText = sheet.getRangeByIndex(startRow, 2);
    cellText.setText('Sunday');

    sheet.getRangeByIndex(startRow, 1, startRow, 2).cellStyle.borders.all.lineStyle =
        LineStyle.thin;
  }

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

    final headers = [
      'User',
      'Scan In 1', 'Scan Out 1',
      'Scan In 2', 'Scan Out 2',
      'Scan In 3', 'Scan Out 3',
      'Lunch (h)',
      'OT (h)',
    ];
    addHeaderRow(sheet, headers, 2);
    setColumnWidths(sheet, [25, 12, 12, 12, 12, 12, 12, 12, 12]);

    final usersToExport = selectedUserId != null ? [selectedUserId] : userNames.keys.toList();

    for (int i = 0; i < usersToExport.length; i++) {
      final uid = usersToExport[i];
      final dateStr = DateService.toStorageDate(selectedDate);
      final record = attendanceMap[uid]?[dateStr]?.split('|') ?? List.filled(6, '');
      appendRow(sheet, i + 3, [userNames[uid] ?? uid, ...record],
          alternate: i % 2 != 0,
          isSunday: selectedDate.weekday == DateTime.sunday);

      final rowNum = i + 3;

      // Lunch formula = ScanIn2 - ScanOut1
      sheet.getRangeByIndex(rowNum, 8).formula = '=(D$rowNum-C$rowNum)*24';
      sheet.getRangeByIndex(rowNum, 8).numberFormat = '0.00';
      sheet.getRangeByIndex(rowNum, 8).cellStyle.borders.all.lineStyle = LineStyle.thin;

      // OT formula = last non-empty ScanOut - 17:00
      sheet.getRangeByIndex(rowNum, 9).formula =
      '=IF(G$rowNum<>"",(G$rowNum-TIME(17,0,0))*24,IF(E$rowNum<>"",(E$rowNum-TIME(17,0,0))*24,IF(C$rowNum<>"",(C$rowNum-TIME(17,0,0))*24,0)))';
      sheet.getRangeByIndex(rowNum, 9).numberFormat = '0.00';
      sheet.getRangeByIndex(rowNum, 9).cellStyle.borders.all.lineStyle = LineStyle.thin;
    }

    // Totals for Day
    final totalRow = usersToExport.length + 3;
    sheet.getRangeByIndex(totalRow, 7).setText('Total');
    sheet.getRangeByIndex(totalRow, 7).cellStyle.bold = true;
    sheet.getRangeByIndex(totalRow, 7).cellStyle.borders.all.lineStyle = LineStyle.thin;

    sheet.getRangeByIndex(totalRow, 8).formula = 'SUM(H3:H${totalRow - 1})';
    sheet.getRangeByIndex(totalRow, 8).numberFormat = '0.00';
    sheet.getRangeByIndex(totalRow, 8).cellStyle.borders.all.lineStyle = LineStyle.thin;

    sheet.getRangeByIndex(totalRow, 9).formula = 'SUM(I3:I${totalRow - 1})';
    sheet.getRangeByIndex(totalRow, 9).numberFormat = '0.00';
    sheet.getRangeByIndex(totalRow, 9).cellStyle.borders.all.lineStyle = LineStyle.thin;

    addLegend(sheet, totalRow + 2);
    _saveExcelFile(workbook, 'attendance-${DateService.toStorageDate(selectedDate)}.xlsx');
  }

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

      final headers = [
        'Date',
        'Scan In 1', 'Scan Out 1',
        'Scan In 2', 'Scan Out 2',
        'Scan In 3', 'Scan Out 3',
        'Lunch (h)',
        'OT (h)',
      ];
      addHeaderRow(sheet, headers, 2);
      setColumnWidths(sheet, [12, 12, 12, 12, 12, 12, 12, 12, 12]);

      final days = attendanceMap[uid]?.keys.toList() ?? [];
      for (int j = 0; j < days.length; j++) {
        final dayStr = days[j];
        final dt = DateTime.parse(dayStr);
        final record = attendanceMap[uid]?[dayStr]?.split('|') ?? List.filled(6, '');
        appendRow(sheet, j + 3, [dayStr, ...record],
            isSunday: dt.weekday == DateTime.sunday,
            alternate: j % 2 != 0);

        final rowNum = j + 3;

        // Lunch = ScanIn2 - ScanOut1
        sheet.getRangeByIndex(rowNum, 8).formula = '=(D$rowNum-C$rowNum)*24';
        sheet.getRangeByIndex(rowNum, 8).numberFormat = '0.00';
        sheet.getRangeByIndex(rowNum, 8).cellStyle.borders.all.lineStyle = LineStyle.thin;

        // OT = last non-empty ScanOut - 17:00
        sheet.getRangeByIndex(rowNum, 9).formula =
        '=IF(G$rowNum<>"",(G$rowNum-TIME(17,0,0))*24,IF(E$rowNum<>"",(E$rowNum-TIME(17,0,0))*24,IF(C$rowNum<>"",(C$rowNum-TIME(17,0,0))*24,0)))';
        sheet.getRangeByIndex(rowNum, 9).numberFormat = '0.00';
        sheet.getRangeByIndex(rowNum, 9).cellStyle.borders.all.lineStyle = LineStyle.thin;
      }

      // Totals for Month
      final totalRow = days.length + 3;
      sheet.getRangeByIndex(totalRow, 7).setText('Total');
      sheet.getRangeByIndex(totalRow, 7).cellStyle.bold = true;
      sheet.getRangeByIndex(totalRow, 7).cellStyle.borders.all.lineStyle = LineStyle.thin;

      sheet.getRangeByIndex(totalRow, 8).formula = 'SUM(H3:H${totalRow - 1})';
      sheet.getRangeByIndex(totalRow, 8).numberFormat = '0.00';
      sheet.getRangeByIndex(totalRow, 8).cellStyle.borders.all.lineStyle = LineStyle.thin;

      sheet.getRangeByIndex(totalRow, 9).formula = 'SUM(I3:I${totalRow - 1})';
      sheet.getRangeByIndex(totalRow, 9).numberFormat = '0.00';
      sheet.getRangeByIndex(totalRow, 9).cellStyle.borders.all.lineStyle = LineStyle.thin;

      addLegend(sheet, totalRow + 2);
    }

    final fileName = selectedDate != null
        ? 'attendance-${DateService.toMonthString(selectedDate)}.xlsx'
        : 'attendance.xlsx';

    _saveExcelFile(workbook, fileName);
  }

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
