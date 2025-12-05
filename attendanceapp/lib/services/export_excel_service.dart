import 'dart:typed_data';
import 'dart:html' as html;
import 'package:syncfusion_flutter_xlsio/xlsio.dart';
import '../services/date_service.dart';

/// ======================
///   STATUS CONFIG
/// ======================

class StatusConfig {
  /// Expected work hours for this status.
  /// null means "N/A" (not applicable).
  final double? expectedHours;

  const StatusConfig(this.expectedHours);
}

/// Easy-to-extend status → config map.
/// Add new statuses here later.
const Map<String, StatusConfig> kStatusConfigs = {
  'full_day': StatusConfig(7.5),
  'halfday': StatusConfig(4.0),
  'annual_leave': StatusConfig(null),
  'unpaid_leave': StatusConfig(null),
  'holiday': StatusConfig(0.0),
  'mc': StatusConfig(0.0),
  'sun': StatusConfig(0.0), // Sunday: expected 0 hours
};

String _normalizeStatus(String raw) => raw.trim().toLowerCase();

/// Define attendance columns in Excel (1-based indices via [colIndex])
enum AttendanceColumn {
  userOrDate,        // col A: "User" (day) or "Date" (month)
  scanIn1,           // col B
  scanOut1,          // col C
  scanIn2,           // col D
  scanOut2,          // col E
  scanIn3,           // col F
  scanOut3,          // col G
  status,            // col H: status code (full_day, halfday, etc.)
  expectedWorkHour,  // col I: expected work hours (number or "N/A")
  workHour,          // col J: total worked hours
  overtime,          // col K: worked - expected, with threshold 0.5
  undertime,         // col L: expected - worked, with threshold 0.15
  present,           // col M: SUN / P/H / U/L / A/L / MC / HF / 1 / 0
}

/// Helper: Excel columns are 1-based
int colIndex(AttendanceColumn col) => col.index + 1;

/// ======================
///   EXPORT SERVICE
/// ======================

class ExportExcelService {
  static Workbook _createWorkbook() => Workbook();

  // Row constants
  static const int infoHeaderRow = 1;
  static const int headerRow = 2;
  static const int firstDataRow = 3;

  /// Info header (top line) such as:
  /// "Attendance on 2025-12-05" or "Alice Attendance for Mar 2025"
  static void createInfoHeader(Worksheet sheet, String title) {
    final cell =
    sheet.getRangeByIndex(infoHeaderRow, colIndex(AttendanceColumn.userOrDate));
    cell.setText(title);
    cell.cellStyle.bold = true;
    cell.cellStyle.hAlign = HAlignType.left;
    cell.cellStyle.vAlign = VAlignType.center;
  }

  /// Column header row
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

  /// Append a row of raw values (User/Date + scan times + status),
  /// with background coloring & borders.
  ///
  /// Time-like strings "HH:mm" are converted to Excel time values.
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
        // Try to parse "HH:mm"
        try {
          final parts = val.split(':');
          if (parts.length == 2) {
            final dt =
            DateTime(0, 1, 1, int.parse(parts[0]), int.parse(parts[1]));
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

  /// Set column widths, 1-based
  static void setColumnWidths(Worksheet sheet, List<double> widths) {
    for (int i = 0; i < widths.length; i++) {
      final range = sheet.getRangeByIndex(1, i + 1);
      range.columnWidth = widths[i];
    }
  }

  /// Add a legend section below the table (still shows Sunday color meaning)
  static void addLegend(Worksheet sheet, int startRow) {
    // Title
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

    sheet
        .getRangeByIndex(startRow + 1, 1, startRow + 1, 2)
        .cellStyle
        .borders
        .all
        .lineStyle = LineStyle.thin;
  }

  /// Excel column index → column letter(s) (1 → A, 27 → AA, etc.)
  static String _excelColLetter(int colIndex) {
    var dividend = colIndex;
    var colLetter = '';
    while (dividend > 0) {
      final modulo = (dividend - 1) % 26;
      colLetter = String.fromCharCode(65 + modulo) + colLetter;
      dividend = ((dividend - modulo) / 26).floor();
    }
    return colLetter;
  }

  /// Compute work hours in Dart from 3 scan pairs:
  /// (out1 - in1) + (out2 - in2) + (out3 - in3)
  /// times are "HH:mm" or empty.
  static double _calculateWorkHoursFromStrings(List<String> scans) {
    double totalHours = 0.0;

    double pairHours(String? inStr, String? outStr) {
      if (inStr == null ||
          outStr == null ||
          inStr.trim().isEmpty ||
          outStr.trim().isEmpty) {
        return 0.0;
      }
      try {
        final inParts = inStr.split(':');
        final outParts = outStr.split(':');
        if (inParts.length != 2 || outParts.length != 2) return 0.0;

        final inDt =
        DateTime(0, 1, 1, int.parse(inParts[0]), int.parse(inParts[1]));
        final outDt =
        DateTime(0, 1, 1, int.parse(outParts[0]), int.parse(outParts[1]));
        final diff = outDt.difference(inDt).inMinutes / 60.0;
        return diff > 0 ? diff : 0.0;
      } catch (_) {
        return 0.0;
      }
    }

    final in1 = scans.length > 0 ? scans[0] : '';
    final out1 = scans.length > 1 ? scans[1] : '';
    final in2 = scans.length > 2 ? scans[2] : '';
    final out2 = scans.length > 3 ? scans[3] : '';
    final in3 = scans.length > 4 ? scans[4] : '';
    final out3 = scans.length > 5 ? scans[5] : '';

    totalHours += pairHours(in1, out1);
    totalHours += pairHours(in2, out2);
    totalHours += pairHours(in3, out3);

    return totalHours;
  }

  /// Compute "present" string based on rules:
  /// - If Sunday → SUN
  /// - Else if status = holiday → P/H
  /// - Else if unpaid_leave → U/L
  /// - Else if annual_leave → A/L
  /// - Else if mc → MC
  /// - Else if workHours > 0 and status = halfday → HF
  /// - Else if workHours > 0 → 1
  /// - Else → 0
  static String _calculatePresent({
    required bool isSunday,
    required String statusCode,
    required double workHours,
  }) {
    final s = _normalizeStatus(statusCode);

    if (isSunday) return 'SUN';
    if (s == 'holiday') return 'P/H';
    if (s == 'unpaid_leave') return 'U/L';
    if (s == 'annual_leave') return 'A/L';
    if (s == 'mc') return 'MC';

    if (workHours > 0) {
      if (s == 'halfday' || s == 'half_day') return 'HF';
      return '1';
    }

    return '0';
  }

  /// ======================
  ///   DAY ATTENDANCE
  /// ======================
  ///
  /// Columns:
  /// A: User
  /// B–G: Scan In/Out 1–3
  /// H: Status
  /// I: Expected Workhour
  /// J: Workhour
  /// K: Overtime
  /// L: Undertime
  /// M: Present
  static void exportDayAttendance({
    required Map<String, Map<String, String>> attendanceMap,
    required Map<String, String> userNames,
    required DateTime selectedDate,
    String? selectedUserId,
  }) {
    final workbook = _createWorkbook();
    final sheet = workbook.worksheets[0];
    sheet.name = 'Attendance';

    final dateStr = DateService.toStorageDate(selectedDate);
    createInfoHeader(sheet, 'Attendance on $dateStr');

    final headers = [
      'User',
      'Scan In 1',
      'Scan Out 1',
      'Scan In 2',
      'Scan Out 2',
      'Scan In 3',
      'Scan Out 3',
      'Status',
      'Expected Workhour (h)',
      'Workhour (h)',
      'Overtime (h)',
      'Undertime (h)',
      'Present',
    ];
    addHeaderRow(sheet, headers, headerRow);

    // Widths for A–M
    setColumnWidths(sheet, [
      25, // User
      12, // In1
      12, // Out1
      12, // In2
      12, // Out2
      12, // In3
      12, // Out3
      16, // Status
      20, // Expected
      16, // Workhour
      16, // OT
      16, // Undertime
      10, // Present
    ]);

    final usersToExport =
    selectedUserId != null ? [selectedUserId] : userNames.keys.toList();

    // Precompute column letters used in formulas
    final in1ColLetter = _excelColLetter(colIndex(AttendanceColumn.scanIn1));
    final out1ColLetter = _excelColLetter(colIndex(AttendanceColumn.scanOut1));
    final in2ColLetter = _excelColLetter(colIndex(AttendanceColumn.scanIn2));
    final out2ColLetter = _excelColLetter(colIndex(AttendanceColumn.scanOut2));
    final in3ColLetter = _excelColLetter(colIndex(AttendanceColumn.scanIn3));
    final out3ColLetter = _excelColLetter(colIndex(AttendanceColumn.scanOut3));

    final expectedColLetter =
    _excelColLetter(colIndex(AttendanceColumn.expectedWorkHour));
    final workColLetter =
    _excelColLetter(colIndex(AttendanceColumn.workHour));
    final overtimeColLetter =
    _excelColLetter(colIndex(AttendanceColumn.overtime));
    final undertimeColLetter =
    _excelColLetter(colIndex(AttendanceColumn.undertime));
    final presentColLetter =
    _excelColLetter(colIndex(AttendanceColumn.present));

    final isSunday = selectedDate.weekday == DateTime.sunday;

    for (int i = 0; i < usersToExport.length; i++) {
      final uid = usersToExport[i];
      final recordString = attendanceMap[uid]?[dateStr] ?? '';
      final parts = recordString.split('|');

      // First 6 entries: scanIn/Out 1–3
      final scans = List<String>.generate(
        6,
            (index) => (index < parts.length) ? parts[index] : '',
      );

      // 7th entry (index 6): status code, default full_day
      final rawStatus =
      (parts.length > 6 && parts[6].trim().isNotEmpty) ? parts[6] : 'full_day';
      var normStatus = _normalizeStatus(rawStatus);
      if (isSunday) {
        normStatus = 'sun';
      }

      final rowNum = firstDataRow + i;

      // 1) Write User + scan times + status
      final displayName = userNames[uid] ?? uid;
      appendRow(
        sheet,
        rowNum,
        [
          displayName,
          ...scans,
          normStatus, // Status text in column H
        ],
        alternate: i % 2 != 0,
        isSunday: isSunday,
      );

      // 2) Expected Workhour (from config)
      final statusConfig =
          kStatusConfigs[normStatus] ?? kStatusConfigs['full_day']!;
      final expectedCell =
      sheet.getRangeByIndex(rowNum, colIndex(AttendanceColumn.expectedWorkHour));
      if (statusConfig.expectedHours == null) {
        expectedCell.setText('N/A');
      } else {
        expectedCell.setNumber(statusConfig.expectedHours!);
        expectedCell.numberFormat = '0.00';
      }
      expectedCell.cellStyle.borders.all.lineStyle = LineStyle.thin;

      // 3) Workhour formula: sum of (out - in) * 24
      final workCell =
      sheet.getRangeByIndex(rowNum, colIndex(AttendanceColumn.workHour));
      if (isSunday) {
        workCell
          ..setNumber(0)
          ..numberFormat = '0.00';
      } else {
        workCell
          ..formula =
              '=(IF(AND($out1ColLetter$rowNum<>"",$in1ColLetter$rowNum<>""),'
              '$out1ColLetter$rowNum-$in1ColLetter$rowNum,0)'
              '+IF(AND($out2ColLetter$rowNum<>"",$in2ColLetter$rowNum<>""),'
              '$out2ColLetter$rowNum-$in2ColLetter$rowNum,0)'
              '+IF(AND($out3ColLetter$rowNum<>"",$in3ColLetter$rowNum<>""),'
              '$out3ColLetter$rowNum-$in3ColLetter$rowNum,0))*24';
        workCell.numberFormat = '0.00';
      }
      workCell.cellStyle.borders.all.lineStyle = LineStyle.thin;

      // 4) Overtime = workhour - expected, threshold > 0.5
      final expectedRef = '$expectedColLetter$rowNum';
      final workRef = '$workColLetter$rowNum';
      final overtimeCell =
      sheet.getRangeByIndex(rowNum, colIndex(AttendanceColumn.overtime));
      if (isSunday) {
        overtimeCell
          ..setNumber(0)
          ..numberFormat = '0.00';
      } else {
        overtimeCell
          ..formula =
              '=IF(OR($expectedRef="N/A",$expectedRef="",NOT(ISNUMBER($expectedRef))),'
              '0,'
              'IF($workRef-$expectedRef>0.5,$workRef-$expectedRef,0))'
          ..numberFormat = '0.00';
      }
      overtimeCell.cellStyle.borders.all.lineStyle = LineStyle.thin;

      // 5) Undertime = expected - workhour, threshold > 0.15
      final undertimeCell =
      sheet.getRangeByIndex(rowNum, colIndex(AttendanceColumn.undertime));
      if (isSunday) {
        undertimeCell
          ..setNumber(0)
          ..numberFormat = '0.00';
      } else {
        undertimeCell
          ..formula =
              '=IF(OR($expectedRef="N/A",$expectedRef="",NOT(ISNUMBER($expectedRef))),'
              '0,'
              'IF($expectedRef-$workRef>0.15,$expectedRef-$workRef,0))'
          ..numberFormat = '0.00';
      }
      undertimeCell.cellStyle.borders.all.lineStyle = LineStyle.thin;

      // 6) Present (computed in Dart)
      final workHoursForPresent = _calculateWorkHoursFromStrings(scans);
      final present = _calculatePresent(
        isSunday: isSunday,
        statusCode: normStatus,
        workHours: workHoursForPresent,
      );
      final presentCell =
      sheet.getRangeByIndex(rowNum, colIndex(AttendanceColumn.present));
      presentCell
        ..setText(present)
        ..cellStyle.borders.all.lineStyle = LineStyle.thin;

      // 🔶 Ensure Sunday orange covers all the extra columns too
      if (isSunday) {
        const sundayColor = '#FFA500';
        for (final col in [
          AttendanceColumn.status,
          AttendanceColumn.expectedWorkHour,
          AttendanceColumn.workHour,
          AttendanceColumn.overtime,
          AttendanceColumn.undertime,
          AttendanceColumn.present,
        ]) {
          sheet
              .getRangeByIndex(rowNum, colIndex(col))
              .cellStyle
              .backColor = sundayColor;
        }
      }
    }

    // Totals row
    final totalRow = firstDataRow + usersToExport.length;

    // Label "Total" in the last scan column (Scan Out 3)
    final totalLabelCell =
    sheet.getRangeByIndex(totalRow, colIndex(AttendanceColumn.scanOut3));
    totalLabelCell
      ..setText('Total')
      ..cellStyle.bold = true
      ..cellStyle.borders.all.lineStyle = LineStyle.thin;

    // SUM Workhour
    final workFrom = '$workColLetter$firstDataRow';
    final workTo = '$workColLetter${totalRow - 1}';
    final totalWorkCell =
    sheet.getRangeByIndex(totalRow, colIndex(AttendanceColumn.workHour));
    totalWorkCell
      ..formula = 'SUM($workFrom:$workTo)'
      ..numberFormat = '0.00'
      ..cellStyle.borders.all.lineStyle = LineStyle.thin;

    // SUM Overtime
    final otFrom = '$overtimeColLetter$firstDataRow';
    final otTo = '$overtimeColLetter${totalRow - 1}';
    final totalOtCell =
    sheet.getRangeByIndex(totalRow, colIndex(AttendanceColumn.overtime));
    totalOtCell
      ..formula = 'SUM($otFrom:$otTo)'
      ..numberFormat = '0.00'
      ..cellStyle.borders.all.lineStyle = LineStyle.thin;

    // SUM Undertime
    final utFrom = '$undertimeColLetter$firstDataRow';
    final utTo = '$undertimeColLetter${totalRow - 1}';
    final totalUtCell =
    sheet.getRangeByIndex(totalRow, colIndex(AttendanceColumn.undertime));
    totalUtCell
      ..formula = 'SUM($utFrom:$utTo)'
      ..numberFormat = '0.00'
      ..cellStyle.borders.all.lineStyle = LineStyle.thin;

    // Total Present (1 = full day, HF = 0.5)
    final presentFrom = '$presentColLetter$firstDataRow';
    final presentTo = '$presentColLetter${totalRow - 1}';
    final totalPresentCell =
    sheet.getRangeByIndex(totalRow, colIndex(AttendanceColumn.present));
    totalPresentCell
      ..formula =
          '=COUNTIF($presentFrom:$presentTo,"1")+0.5*COUNTIF($presentFrom:$presentTo,"HF")'
      ..cellStyle.bold = true
      ..cellStyle.borders.all.lineStyle = LineStyle.thin;

    addLegend(sheet, totalRow + 2);
    _saveExcelFile(workbook, 'attendance-$dateStr.xlsx');
  }

  /// ======================
  ///   MONTH ATTENDANCE (26 → 25) – SHOW ALL DATES + SUMMARY
  /// ======================
  ///
  /// One sheet per user:
  /// A: Date
  /// B–G: Scan In/Out 1–3
  /// H: Status
  /// I: Expected Workhour
  /// J: Workhour
  /// K: Overtime
  /// L: Undertime
  /// M: Present
  static void exportMonthAttendance({
    required Map<String, Map<String, String>> attendanceMap,
    required Map<String, String> userNames,
    DateTime? selectedDate,
    String? selectedUserId,
  }) {
    final workbook = _createWorkbook();
    final defaultSheet = workbook.worksheets[0];

    final usersToExport =
    selectedUserId != null ? [selectedUserId] : attendanceMap.keys.toList();

    // Custom month range: 26 prev month → 25 selected month
    DateTime? periodStart;
    DateTime? periodEnd;
    String monthStr = '';

    if (selectedDate != null) {
      final int year = selectedDate.year;
      final int month = selectedDate.month;

      final int prevMonth = month == 1 ? 12 : month - 1;
      final int prevYear = month == 1 ? year - 1 : year;

      periodStart = DateTime(prevYear, prevMonth, 26);
      periodEnd = DateTime(year, month, 25);

      monthStr = DateService.toMonthString(selectedDate);
    }

    // Precompute column letters for formulas
    final in1ColLetter = _excelColLetter(colIndex(AttendanceColumn.scanIn1));
    final out1ColLetter = _excelColLetter(colIndex(AttendanceColumn.scanOut1));
    final in2ColLetter = _excelColLetter(colIndex(AttendanceColumn.scanIn2));
    final out2ColLetter = _excelColLetter(colIndex(AttendanceColumn.scanOut2));
    final in3ColLetter = _excelColLetter(colIndex(AttendanceColumn.scanIn3));
    final out3ColLetter = _excelColLetter(colIndex(AttendanceColumn.scanOut3));

    final expectedColLetter =
    _excelColLetter(colIndex(AttendanceColumn.expectedWorkHour));
    final workColLetter =
    _excelColLetter(colIndex(AttendanceColumn.workHour));
    final overtimeColLetter =
    _excelColLetter(colIndex(AttendanceColumn.overtime));
    final undertimeColLetter =
    _excelColLetter(colIndex(AttendanceColumn.undertime));
    final presentColLetter =
    _excelColLetter(colIndex(AttendanceColumn.present));
    final statusColLetter =
    _excelColLetter(colIndex(AttendanceColumn.status));

    for (int i = 0; i < usersToExport.length; i++) {
      final uid = usersToExport[i];
      final sheetName = userNames[uid] ?? uid;

      Worksheet sheet;
      if (i == 0) {
        sheet = defaultSheet;
        sheet.name = sheetName;
      } else {
        sheet = workbook.worksheets.addWithName(sheetName);
      }

      final title = selectedDate != null
          ? '$sheetName Attendance for $monthStr'
          : '$sheetName Attendance';
      createInfoHeader(sheet, title);

      final headers = [
        'Date',
        'Scan In 1',
        'Scan Out 1',
        'Scan In 2',
        'Scan Out 2',
        'Scan In 3',
        'Scan Out 3',
        'Status',
        'Expected Workhour (h)',
        'Workhour (h)',
        'Overtime (h)',
        'Undertime (h)',
        'Present',
      ];
      addHeaderRow(sheet, headers, headerRow);

      setColumnWidths(sheet, [
        12, // Date
        12,
        12,
        12,
        12,
        12,
        12,
        16, // Status
        20, // Expected
        16, // Workhour
        16, // OT
        16, // Undertime
        10, // Present
      ]);

      // ----- Build full date list -----
      final days = <String>[];

      if (periodStart != null && periodEnd != null) {
        // Use full range 26 → 25, even if empty in attendanceMap
        var current = periodStart;
        while (!current.isAfter(periodEnd)) {
          final dayStr = DateService.toStorageDate(current); // "yyyy-MM-dd"
          days.add(dayStr);
          current = current.add(const Duration(days: 1));
        }
      } else {
        // Fallback: no selectedDate → use whatever keys exist
        final allKeys = attendanceMap[uid]?.keys.toList() ?? [];
        allKeys.sort();
        days.addAll(allKeys);
      }

      for (int j = 0; j < days.length; j++) {
        final dayStr = days[j];

        DateTime dt;
        try {
          dt = DateTime.parse(dayStr);
        } catch (_) {
          continue;
        }

        final recordString = attendanceMap[uid]?[dayStr] ?? '';
        final parts = recordString.split('|');

        final scans = List<String>.generate(
          6,
              (index) => (index < parts.length) ? parts[index] : '',
        );
        final rawStatus =
        (parts.length > 6 && parts[6].trim().isNotEmpty) ? parts[6] : 'full_day';
        var normStatus = _normalizeStatus(rawStatus);

        final rowNum = firstDataRow + j;
        final isSunday = dt.weekday == DateTime.sunday;
        if (isSunday) {
          normStatus = 'sun';
        }

        // 1) Date + scans + status
        appendRow(
          sheet,
          rowNum,
          [
            dayStr,
            ...scans,
            normStatus,
          ],
          isSunday: isSunday,
          alternate: j % 2 != 0,
        );

        // 2) Expected Workhour
        final statusConfig =
            kStatusConfigs[normStatus] ?? kStatusConfigs['full_day']!;
        final expectedCell =
        sheet.getRangeByIndex(rowNum, colIndex(AttendanceColumn.expectedWorkHour));
        if (statusConfig.expectedHours == null) {
          expectedCell.setText('N/A');
        } else {
          expectedCell.setNumber(statusConfig.expectedHours!);
          expectedCell.numberFormat = '0.00';
        }
        expectedCell.cellStyle.borders.all.lineStyle = LineStyle.thin;

        // 3) Workhour formula (sum of 3 pairs)
        final workCell =
        sheet.getRangeByIndex(rowNum, colIndex(AttendanceColumn.workHour));
        if (isSunday) {
          workCell
            ..setNumber(0)
            ..numberFormat = '0.00';
        } else {
          workCell
            ..formula =
                '=(IF(AND($out1ColLetter$rowNum<>"",$in1ColLetter$rowNum<>""),'
                '$out1ColLetter$rowNum-$in1ColLetter$rowNum,0)'
                '+IF(AND($out2ColLetter$rowNum<>"",$in2ColLetter$rowNum<>""),'
                '$out2ColLetter$rowNum-$in2ColLetter$rowNum,0)'
                '+IF(AND($out3ColLetter$rowNum<>"",$in3ColLetter$rowNum<>""),'
                '$out3ColLetter$rowNum-$in3ColLetter$rowNum,0))*24'
            ..numberFormat = '0.00';
        }
        workCell.cellStyle.borders.all.lineStyle = LineStyle.thin;

        // 4) Overtime = workhour - expected, threshold > 0.5
        final expectedRef = '$expectedColLetter$rowNum';
        final workRef = '$workColLetter$rowNum';
        final overtimeCell =
        sheet.getRangeByIndex(rowNum, colIndex(AttendanceColumn.overtime));
        if (isSunday) {
          overtimeCell
            ..setNumber(0)
            ..numberFormat = '0.00';
        } else {
          overtimeCell
            ..formula =
                '=IF(OR($expectedRef="N/A",$expectedRef="",NOT(ISNUMBER($expectedRef))),'
                '0,'
                'IF($workRef-$expectedRef>0.5,$workRef-$expectedRef,0))'
            ..numberFormat = '0.00';
        }
        overtimeCell.cellStyle.borders.all.lineStyle = LineStyle.thin;

        // 5) Undertime = expected - workhour, threshold > 0.15
        final undertimeCell =
        sheet.getRangeByIndex(rowNum, colIndex(AttendanceColumn.undertime));
        if (isSunday) {
          undertimeCell
            ..setNumber(0)
            ..numberFormat = '0.00';
        } else {
          undertimeCell
            ..formula =
                '=IF(OR($expectedRef="N/A",$expectedRef="",NOT(ISNUMBER($expectedRef))),'
                '0,'
                'IF($expectedRef-$workRef>0.15,$expectedRef-$workRef,0))'
            ..numberFormat = '0.00';
        }
        undertimeCell.cellStyle.borders.all.lineStyle = LineStyle.thin;

        // 6) Present (Dart)
        final workHoursForPresent = _calculateWorkHoursFromStrings(scans);
        final present = _calculatePresent(
          isSunday: isSunday,
          statusCode: normStatus,
          workHours: workHoursForPresent,
        );
        final presentCell =
        sheet.getRangeByIndex(rowNum, colIndex(AttendanceColumn.present));
        presentCell
          ..setText(present)
          ..cellStyle.borders.all.lineStyle = LineStyle.thin;

        // 🔶 Ensure Sunday orange covers all the extra columns too
        if (isSunday) {
          const sundayColor = '#FFA500';
          for (final col in [
            AttendanceColumn.status,
            AttendanceColumn.expectedWorkHour,
            AttendanceColumn.workHour,
            AttendanceColumn.overtime,
            AttendanceColumn.undertime,
            AttendanceColumn.present,
          ]) {
            sheet
                .getRangeByIndex(rowNum, colIndex(col))
                .cellStyle
                .backColor = sundayColor;
          }
        }
      }

      // Totals for this user's sheet
      final totalRow = firstDataRow + days.length;

      final totalLabelCell =
      sheet.getRangeByIndex(totalRow, colIndex(AttendanceColumn.scanOut3));
      totalLabelCell
        ..setText('Total')
        ..cellStyle.bold = true
        ..cellStyle.borders.all.lineStyle = LineStyle.thin;

      // SUM Workhour
      final workFrom = '$workColLetter$firstDataRow';
      final workTo = '$workColLetter${totalRow - 1}';
      final totalWorkCell =
      sheet.getRangeByIndex(totalRow, colIndex(AttendanceColumn.workHour));
      totalWorkCell
        ..formula = 'SUM($workFrom:$workTo)'
        ..numberFormat = '0.00'
        ..cellStyle.borders.all.lineStyle = LineStyle.thin;

      // SUM Overtime
      final otFrom = '$overtimeColLetter$firstDataRow';
      final otTo = '$overtimeColLetter${totalRow - 1}';
      final totalOtCell =
      sheet.getRangeByIndex(totalRow, colIndex(AttendanceColumn.overtime));
      totalOtCell
        ..formula = 'SUM($otFrom:$otTo)'
        ..numberFormat = '0.00'
        ..cellStyle.borders.all.lineStyle = LineStyle.thin;

      // SUM Undertime
      final utFrom = '$undertimeColLetter$firstDataRow';
      final utTo = '$undertimeColLetter${totalRow - 1}';
      final totalUtCell =
      sheet.getRangeByIndex(totalRow, colIndex(AttendanceColumn.undertime));
      totalUtCell
        ..formula = 'SUM($utFrom:$utTo)'
        ..numberFormat = '0.00'
        ..cellStyle.borders.all.lineStyle = LineStyle.thin;

      // Total Present (1 = full day, HF = 0.5)
      final presentFrom = '$presentColLetter$firstDataRow';
      final presentTo = '$presentColLetter${totalRow - 1}';
      final totalPresentCell =
      sheet.getRangeByIndex(totalRow, colIndex(AttendanceColumn.present));
      totalPresentCell
        ..formula =
            '=COUNTIF($presentFrom:$presentTo,"1")+0.5*COUNTIF($presentFrom:$presentTo,"HF")'
        ..cellStyle.bold = true
        ..cellStyle.borders.all.lineStyle = LineStyle.thin;

      // ============================================================
      //  EXTRA SUMMARY BLOCK (STATUS COUNT + TOTALS)
      // ============================================================

      int summaryRow = totalRow + 2;

      // Status counts (fixed order)
      final statusSummary = <List<String>>[
        [
          'FULL DAY',
          '=COUNTIF($statusColLetter$firstDataRow:$statusColLetter${totalRow - 1},"full_day")'
        ],
        [
          'HALF DAY',
          '=COUNTIF($statusColLetter$firstDataRow:$statusColLetter${totalRow - 1},"halfday")'
        ],
        [
          'ANNUAL LEAVE',
          '=COUNTIF($statusColLetter$firstDataRow:$statusColLetter${totalRow - 1},"annual_leave")'
        ],
        [
          'UNPAID LEAVE',
          '=COUNTIF($statusColLetter$firstDataRow:$statusColLetter${totalRow - 1},"unpaid_leave")'
        ],
        [
          'HOLIDAY',
          '=COUNTIF($statusColLetter$firstDataRow:$statusColLetter${totalRow - 1},"holiday")'
        ],
        [
          'MC',
          '=COUNTIF($statusColLetter$firstDataRow:$statusColLetter${totalRow - 1},"mc")'
        ],
      ];

      for (final row in statusSummary) {
        sheet.getRangeByIndex(summaryRow, 1).setText(row[0]);
        sheet.getRangeByIndex(summaryRow, 2)
          ..formula = row[1]
          ..numberFormat = '0.0'
          ..cellStyle.borders.all.lineStyle = LineStyle.thin;
        summaryRow++;
      }

      summaryRow++;

      // Total Present Days (1 + 0.5 HF)
      sheet.getRangeByIndex(summaryRow, 1).setText('TOTAL PRESENT DAYS');
      sheet.getRangeByIndex(summaryRow, 2)
        ..formula =
            '=COUNTIF($presentColLetter$firstDataRow:$presentColLetter${totalRow - 1},"1")'
            '+0.5*COUNTIF($presentColLetter$firstDataRow:$presentColLetter${totalRow - 1},"HF")'
        ..numberFormat = '0.0'
        ..cellStyle.borders.all.lineStyle = LineStyle.thin;
      summaryRow++;

      // Total Absent Days (present = 0)
      sheet.getRangeByIndex(summaryRow, 1).setText('TOTAL ABSENT DAYS');
      sheet.getRangeByIndex(summaryRow, 2)
        ..formula =
            '=COUNTIF($presentColLetter$firstDataRow:$presentColLetter${totalRow - 1},"0")'
        ..numberFormat = '0'
        ..cellStyle.borders.all.lineStyle = LineStyle.thin;
      summaryRow++;

      // Total Overtime Hours
      sheet.getRangeByIndex(summaryRow, 1).setText('TOTAL OVERTIME HOURS');
      sheet.getRangeByIndex(summaryRow, 2)
        ..formula = 'SUM($overtimeColLetter$firstDataRow:$overtimeColLetter${totalRow - 1})'
        ..numberFormat = '0.0'
        ..cellStyle.borders.all.lineStyle = LineStyle.thin;
      summaryRow++;

      // Total Undertime Hours
      sheet.getRangeByIndex(summaryRow, 1).setText('TOTAL UNDERTIME HOURS');
      sheet.getRangeByIndex(summaryRow, 2)
        ..formula = 'SUM($undertimeColLetter$firstDataRow:$undertimeColLetter${totalRow - 1})'
        ..numberFormat = '0.0'
        ..cellStyle.borders.all.lineStyle = LineStyle.thin;
      summaryRow++;

      // Total Leave Days (annual + unpaid + holiday + mc)
      sheet.getRangeByIndex(summaryRow, 1).setText('TOTAL LEAVE DAYS');
      sheet.getRangeByIndex(summaryRow, 2)
        ..formula =
            '=COUNTIF($statusColLetter$firstDataRow:$statusColLetter${totalRow - 1},"annual_leave")'
            '+COUNTIF($statusColLetter$firstDataRow:$statusColLetter${totalRow - 1},"unpaid_leave")'
            '+COUNTIF($statusColLetter$firstDataRow:$statusColLetter${totalRow - 1},"holiday")'
            '+COUNTIF($statusColLetter$firstDataRow:$statusColLetter${totalRow - 1},"mc")'
        ..numberFormat = '0'
        ..cellStyle.borders.all.lineStyle = LineStyle.thin;
      summaryRow++;

      // Total Workdays (1 + HF as 1)
      sheet.getRangeByIndex(summaryRow, 1).setText('TOTAL WORKDAYS');
      sheet.getRangeByIndex(summaryRow, 2)
        ..formula =
            '=COUNTIF($presentColLetter$firstDataRow:$presentColLetter${totalRow - 1},"1")'
            '+COUNTIF($presentColLetter$firstDataRow:$presentColLetter${totalRow - 1},"HF")'
        ..numberFormat = '0.0'
        ..cellStyle.borders.all.lineStyle = LineStyle.thin;
      summaryRow++;

      addLegend(sheet, summaryRow + 1);
    }

    final fileName = selectedDate != null
        ? 'attendance-${DateService.toMonthString(selectedDate)}.xlsx'
        : 'attendance.xlsx';

    _saveExcelFile(workbook, fileName);
  }

  /// Save Excel file to browser (Web)
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