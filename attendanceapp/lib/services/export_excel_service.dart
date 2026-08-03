import 'dart:typed_data';
import 'dart:html' as html;
import 'package:syncfusion_flutter_xlsio/xlsio.dart';
import '../services/date_service.dart';
import '../models/attendance_model.dart';
import 'package:attendanceapp/configs_and_tools/debug.dart';

Debug debug = Debug(module: "export_excel_service", enable: true);

//Work Hour Setting Change Here
const double workHour = 7.5;          //half hour = 0.50
const double halfDayWorkHour = workHour/2;
const double noWorkHour = 0.0;

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
final Map<String, StatusConfig> attendanceStatusConfig = {
  Status.FullDay.name : StatusConfig(workHour),
  Status.HalfDay.name : StatusConfig(halfDayWorkHour),
  Status.AL_FullDay.name : StatusConfig(noWorkHour),
  Status.AL_HalfDay.name : StatusConfig(halfDayWorkHour),
  Status.UL_FullDay.name : StatusConfig(noWorkHour),
  Status.UL_HalfDay.name : StatusConfig(halfDayWorkHour),
  Status.PH_FullDay.name : StatusConfig(noWorkHour),
  Status.PH_HalfDay.name : StatusConfig(halfDayWorkHour),
  Status.MC_FullDay.name : StatusConfig(noWorkHour),
  Status.MC_HalfDay.name : StatusConfig(halfDayWorkHour),
  Status.SUN.name : StatusConfig(noWorkHour), // Sunday: expected 0 hours
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
  status,            // col H: status code (fullday, halfday, etc.)
  expectedWorkHour,  // col I: expected work hours (number or "N/A")
  workHour,          // col J: total worked hours
  overtime,          // col K: worked - expected
  undertime,         // col L: expected - worked
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

  /// Adds a dropdown list validation for the given cell (Worksheet, 1‑based).
  static void addStatusDropdown(
      Worksheet sheet,
      int row,
      int col,
      List<String> options,
      ) {
    final validation = sheet.getRangeByIndex(row, col).dataValidation;
    validation.listOfValues = options;
    // Optional: show prompt/error boxes:
    validation.showPromptBox = true;
    validation.promptBoxText = 'Select status';
    validation.showErrorBox = true;
    validation.errorBoxText = 'Please choose a value from the list';
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
    required Map<String, Map<String, Map<String, String>>> attendanceStatusMap,
    required Map<String, String> userNames,
    DateTime? selectedDate,
    DateTime? periodStart,
    DateTime? periodEnd,
    String? selectedUserId,
  }) {
    final workbook = _createWorkbook();
    final defaultSheet = workbook.worksheets[0];

    final usersToExport =
    selectedUserId != null ? [selectedUserId] : attendanceMap.keys.toList();

    String monthStr = '';

    if (selectedDate != null) {
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
    const int statusTableStartRow = 100; // fixed row for Status Table
    final statusTable = attendanceStatusConfig.entries.toList();

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
        final Map<String, String>? statusEntry =
        attendanceStatusMap[uid]?[dayStr];

        String rawStatus = 'n/a';

        if (statusEntry != null) {
          final String? status = statusEntry['status'];
          final String? applicationStatus = statusEntry['applicationStatus'];

          if (status != null) {
            if (applicationStatus == ApplicationStatus.approved.name) {
              rawStatus = status;
            } else if (applicationStatus == ApplicationStatus.declined.name) {
              rawStatus = 'Declined';
            } else if (applicationStatus == ApplicationStatus.pending.name) {
              rawStatus = 'Pending';
            } else {
              rawStatus = 'n/a';
            }
          }
        }

        var normStatus = (_normalizeStatus(rawStatus) == 'n/a' ||
            _normalizeStatus(rawStatus).isEmpty)
            ? (attendanceStatusMap?['status']?.toString() ??
            Status.FullDay.name)
            : _normalizeStatus(rawStatus);

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

        // Add dropdown to the "normStatus" cell
        final include = [
          Status.FullDay,
          Status.AL_FullDay,
          Status.AL_HalfDay,
          Status.UL_FullDay,
          Status.UL_HalfDay,
          Status.MC_FullDay,
          Status.MC_HalfDay,
          Status.PH_FullDay,
          Status.PH_HalfDay,
        ];
        addStatusDropdown(
          sheet,
          rowNum,
          colIndex(AttendanceColumn.status), // status column (H)
          Status.values
              .where((s) => include.contains(s))
              .map((s) => s.name) // or .code if you want codes
              .toList(),
        );

        // 2) Expected Workhour
        final statusConfig =
            attendanceStatusConfig[normStatus] ??
                attendanceStatusConfig[Status.FullDay.name]!;
        final expectedCell =
        sheet.getRangeByIndex(
            rowNum, colIndex(AttendanceColumn.expectedWorkHour));

        expectedCell.formula =
        '=IFERROR(VLOOKUP(H$rowNum,\$A\$${statusTableStartRow +
            1}:\$B\$${statusTableStartRow +
            statusTable.length},2,FALSE),"N/A")';

        // ✅ Add table lining (borders)
        expectedCell.cellStyle.borders.all.lineStyle = LineStyle.thin;
        expectedCell.cellStyle.hAlign = HAlignType.center;
        expectedCell.numberFormat = '0.00';

        // 3) Workhour formula (sum of 3 pairs)
        final workCell =
        sheet.getRangeByIndex(rowNum, colIndex(AttendanceColumn.workHour));
        if (isSunday) {
          workCell
            ..setNumber(0)
            ..numberFormat = '0.000';
        } else {
          workCell
            ..formula =
                '=(IF(AND($out1ColLetter$rowNum<>"",$in1ColLetter$rowNum<>""),'
                '$out1ColLetter$rowNum-$in1ColLetter$rowNum,0)'
                '+IF(AND($out2ColLetter$rowNum<>"",$in2ColLetter$rowNum<>""),'
                '$out2ColLetter$rowNum-$in2ColLetter$rowNum,0)'
                '+IF(AND($out3ColLetter$rowNum<>"",$in3ColLetter$rowNum<>""),'
                '$out3ColLetter$rowNum-$in3ColLetter$rowNum,0))*24'
            ..numberFormat = '0.000';
        }
        workCell.cellStyle.borders.all.lineStyle = LineStyle.thin;

        // 4) Overtime = workhour - expected
        final expectedRef = '$expectedColLetter$rowNum';
        final workRef = '$workColLetter$rowNum';
        final overtimeCell =
        sheet.getRangeByIndex(rowNum, colIndex(AttendanceColumn.overtime));
        if (isSunday) {
          overtimeCell
            ..setNumber(0)
            ..numberFormat = '0.000';
        } else {
          overtimeCell
            ..formula =
                '=IF(OR($expectedRef="N/A",$expectedRef="",NOT(ISNUMBER($expectedRef))),'
                '0,'
                'IF(($workRef-$expectedRef)>0,($workRef-$expectedRef),0))'
            ..numberFormat = '0.000';
        }
        overtimeCell.cellStyle.borders.all.lineStyle = LineStyle.thin;

        // 5) Undertime = expected - workhour
        final undertimeCell =
        sheet.getRangeByIndex(rowNum, colIndex(AttendanceColumn.undertime));
        if (isSunday) {
          undertimeCell
            ..setNumber(0)
            ..numberFormat = '0.000';
        } else {
          undertimeCell
            ..formula =
                '=IF(OR($expectedRef="N/A",$expectedRef="",NOT(ISNUMBER($expectedRef))),'
                '0,'
                'IF(($expectedRef-$workRef)>0,($expectedRef-$workRef),0))'
            ..numberFormat = '0.000';
        }
        undertimeCell.cellStyle.borders.all.lineStyle = LineStyle.thin;
      }

      // Totals for this user's sheet
      final totalRow = firstDataRow + days.length;

      final totalLabelCell =
      sheet.getRangeByIndex(totalRow, colIndex(AttendanceColumn.expectedWorkHour));
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
        ..numberFormat = '0.000'
        ..cellStyle.borders.all.lineStyle = LineStyle.thin;

      // SUM Overtime
      final otFrom = '$overtimeColLetter$firstDataRow';
      final otTo = '$overtimeColLetter${totalRow - 1}';
      final totalOtCell =
      sheet.getRangeByIndex(totalRow, colIndex(AttendanceColumn.overtime));
      totalOtCell
        ..formula = 'SUM($otFrom:$otTo)'
        ..numberFormat = '0.000'
        ..cellStyle.borders.all.lineStyle = LineStyle.thin;

      // SUM Undertime
      final utFrom = '$undertimeColLetter$firstDataRow';
      final utTo = '$undertimeColLetter${totalRow - 1}';
      final totalUtCell =
      sheet.getRangeByIndex(totalRow, colIndex(AttendanceColumn.undertime));
      totalUtCell
        ..formula = 'SUM($utFrom:$utTo)'
        ..numberFormat = '0.000'
        ..cellStyle.borders.all.lineStyle = LineStyle.thin;

      // ============================================================
      //  EXTRA SUMMARY BLOCK (STATUS COUNT + TOTALS)
      // ============================================================
      sheet.getRangeByIndex(totalRow + 2, 2).setText('Day');
      sheet.getRangeByIndex(totalRow + 2, 3).setText('Hour');
      int summaryRow = totalRow + 3;
      int customerRequestCalculationRow = summaryRow;

      final String unpaidLeaveDayCalculationFormula = '=(COUNTIF($statusColLetter$firstDataRow:$statusColLetter${totalRow - 1},"${Status.UL_FullDay.name}")+0.5*COUNTIF($statusColLetter$firstDataRow:$statusColLetter${totalRow - 1},"${Status.UL_HalfDay.name}"))';
      final String unpaidLeaveHourCalculationFormula = unpaidLeaveDayCalculationFormula+'*$workHour';
      final String annualLeaveDayCalculationFormula = '=(COUNTIF($statusColLetter$firstDataRow:$statusColLetter${totalRow - 1},"${Status.AL_FullDay.name}")+0.5*COUNTIF($statusColLetter$firstDataRow:$statusColLetter${totalRow - 1},"${Status.AL_HalfDay.name}"))';
      final String annualLeaveHourCalcutationFormula = annualLeaveDayCalculationFormula+'*$workHour';
      final String publicHolidayDayCalculationFormula = '=(COUNTIF($statusColLetter$firstDataRow:$statusColLetter${totalRow - 1},"${Status.PH_FullDay.name}")+0.5*COUNTIF($statusColLetter$firstDataRow:$statusColLetter${totalRow - 1},"${Status.PH_HalfDay.name}"))';
      final String publicHolidayHourCalculationFormula = publicHolidayDayCalculationFormula+'*$workHour';
      final String mcDayCalculationFormula = '=(COUNTIF($statusColLetter$firstDataRow:$statusColLetter${totalRow - 1},"${Status.MC_FullDay.name}")+0.5*COUNTIF($statusColLetter$firstDataRow:$statusColLetter${totalRow - 1},"${Status.MC_HalfDay.name}"))';
      final String mcHourCalculationFormula = mcDayCalculationFormula+'*$workHour';

      // Status counts (fixed order)
      final statusSummary = <List<String>>[
        [
          'UNPAID LEAVE',
          unpaidLeaveDayCalculationFormula,
          unpaidLeaveHourCalculationFormula
        ],
        [
          'ANNUAL LEAVE',
          annualLeaveDayCalculationFormula,
          annualLeaveHourCalcutationFormula
        ],
        [
          'PUBLIC HOLIDAY',
          publicHolidayDayCalculationFormula,
          publicHolidayHourCalculationFormula
        ],
        [
          'MC',
          mcDayCalculationFormula,
          mcHourCalculationFormula
        ],
      ];

      int? unpaidLeaveRow;
      for (final row in statusSummary) {
        sheet.getRangeByIndex(summaryRow, 1).setText(row[0]);
        sheet.getRangeByIndex(summaryRow, 2)
          ..formula = row[1]
          ..numberFormat = '0.000'
          ..cellStyle.borders.all.lineStyle = LineStyle.thin;
        sheet.getRangeByIndex(summaryRow, 3)
          ..formula = row[2]
          ..numberFormat = '0.000'
          ..cellStyle.borders.all.lineStyle = LineStyle.thin;

        if (row[0] == 'UNPAID LEAVE') {
          unpaidLeaveRow = summaryRow;
        }
        summaryRow++;
      }
      summaryRow++;

      // Total Present Days ([Total Work Hour - Total Overtime + Total Undertime] / WorkHour per day)
      // 🔑 Get Excel cell address of total work hour cell (e.g. "F32")
      final totalWorkAddress = totalWorkCell.addressLocal;
      final totalUnderTime = totalUtCell.addressLocal;
      final totalOverTime = totalOtCell.addressLocal;

      final String totalPresentHourFormula = '($totalWorkAddress-$totalOverTime+$totalUnderTime)';
      final String totalPresentDayFormula = totalPresentHourFormula+'/$workHour';
      final String totalWorkdaysDayFormula = '=(COUNTIF($statusColLetter$firstDataRow:$statusColLetter${totalRow - 1},"<>${Status.SUN.name}"))';
      final String totalWorkdaysHourFormula = totalWorkdaysDayFormula+'*$workHour';
      final String totalOverTimeHourFormula = '(SUM($overtimeColLetter$firstDataRow:$overtimeColLetter${totalRow - 1}))';
      final String totalOverTimeDayFormula = totalOverTimeHourFormula+'/$workHour';
      final String totalHalfDayOvertimeHourFormula = '(SUMIF($statusColLetter$firstDataRow:$statusColLetter${totalRow - 1},"<>${Status.FullDay.name}",$overtimeColLetter$firstDataRow:$overtimeColLetter${totalRow - 1}))';
      final String totalHalfDayOvertimeDayFormula = totalHalfDayOvertimeHourFormula+'/$workHour';
      final String totalUnderTimeHourFormula = '(SUM($undertimeColLetter$firstDataRow:$undertimeColLetter${totalRow - 1}))';
      final String totalUnderTimeDayFormula = totalUnderTimeHourFormula+'/$workHour';

      sheet.getRangeByIndex(summaryRow, 1).setText('TOTAL PRESENT DAYS');
      sheet.getRangeByIndex(summaryRow, 2)
        ..formula = totalPresentDayFormula
        ..numberFormat = '0.000'
        ..cellStyle.borders.all.lineStyle = LineStyle.thin;
      sheet.getRangeByIndex(summaryRow, 3)
        ..formula = totalPresentHourFormula
        ..numberFormat = '0.000'
        ..cellStyle.borders.all.lineStyle = LineStyle.thin;
      summaryRow++;

      // Total Workdays

      sheet.getRangeByIndex(summaryRow, 1).setText('TOTAL WORKDAYS');
      sheet.getRangeByIndex(summaryRow, 2)
        ..formula = totalWorkdaysDayFormula
        ..numberFormat = '0.000'
        ..cellStyle.borders.all.lineStyle = LineStyle.thin;
      sheet.getRangeByIndex(summaryRow, 3)
        ..formula = totalWorkdaysHourFormula
        ..numberFormat = '0.000'
        ..cellStyle.borders.all.lineStyle = LineStyle.thin;
      summaryRow++;

      // Total Overtime
      final totalOvertimeRow = summaryRow;

      sheet.getRangeByIndex(summaryRow, 1)
          .setText('TOTAL OVERTIME');
      sheet.getRangeByIndex(summaryRow, 2)
        ..formula = totalOverTimeDayFormula
        ..numberFormat = '0.000'
        ..cellStyle.borders.all.lineStyle = LineStyle.thin;
      sheet.getRangeByIndex(summaryRow, 3)
        ..formula = totalOverTimeHourFormula
        ..numberFormat = '0.000'
        ..cellStyle.borders.all.lineStyle = LineStyle.thin;
      summaryRow++;

      // Total Halfday Overtime
      final totalHalfdayOvertimeRow = summaryRow;

      sheet.getRangeByIndex(summaryRow, 1)
          .setText('TOTAL OVERTIME (HALFDAY)');
      sheet.getRangeByIndex(summaryRow, 2)
        ..formula = totalHalfDayOvertimeDayFormula
        ..numberFormat = '0.000'
        ..cellStyle.borders.all.lineStyle = LineStyle.thin;
      sheet.getRangeByIndex(summaryRow, 3)
        ..formula = totalHalfDayOvertimeHourFormula
        ..numberFormat = '0.000'
        ..cellStyle.borders.all.lineStyle = LineStyle.thin;
      summaryRow++;

      // Total Effective Overtime
      final String totalEffectiveOvertimeHourFormula = '=(C$totalOvertimeRow-C$totalHalfdayOvertimeRow)';
      final String totalEffectiveOvertimeDayFormula = totalEffectiveOvertimeHourFormula+'/$workHour';
      sheet.getRangeByIndex(summaryRow, 1)
          .setText('TOTAL OVERTIME (EFFECTIVE)');
      sheet.getRangeByIndex(summaryRow, 2)
        ..formula = totalEffectiveOvertimeDayFormula
        ..numberFormat = '0.000'
        ..cellStyle.borders.all.lineStyle = LineStyle.thin;
      sheet.getRangeByIndex(summaryRow, 3)
        ..formula = totalEffectiveOvertimeHourFormula
        ..numberFormat = '0.000'
        ..cellStyle.borders.all.lineStyle = LineStyle.thin;
      summaryRow++;

      // Total Undertime
      sheet.getRangeByIndex(summaryRow, 1).setText('TOTAL UNDERTIME');
      sheet.getRangeByIndex(summaryRow, 2)
        ..formula = totalUnderTimeDayFormula
        ..numberFormat = '0.000'
        ..cellStyle.borders.all.lineStyle = LineStyle.thin;
      sheet.getRangeByIndex(summaryRow, 3)
        ..formula = totalUnderTimeHourFormula
        ..numberFormat = '0.000'
        ..cellStyle.borders.all.lineStyle = LineStyle.thin;
      final totalUndertimeRow = summaryRow;
      summaryRow++;

      addLegend(sheet, summaryRow + 1);

      // ✅ Auto-fit Column A (Date / User)
      sheet.autoFitColumn(1);

      // Add StatusConfig table at fixed row
      sheet.getRangeByIndex(statusTableStartRow, 1).setText('Status Table');
      sheet.getRangeByIndex(statusTableStartRow, 1).cellStyle.bold = true;

      for (int i = 0; i < statusTable.length; i++) {
        final row = statusTableStartRow + i + 1;
        sheet.getRangeByIndex(row, 1).setText(statusTable[i].key); // Status code
        final hours = statusTable[i].value.expectedHours;
        if (hours != null) {
          sheet.getRangeByIndex(row, 2).setNumber(hours); // Expected hours
        } else {
          sheet.getRangeByIndex(row, 2).setText('N/A');
        }
      }

      customerRequestCalculation(
        sheet,
        customerRequestCalculationRow,
        5,
        unpaidLeaveRow!,
        totalUndertimeRow,
      );
    }

    final fileName = selectedDate != null
        ? 'attendance-${DateService.toMonthString(selectedDate)}.xlsx'
        : 'attendance.xlsx';

    _saveExcelFile(workbook, fileName);
  }

  static void customerRequestCalculation(
      Worksheet sheet,
      int startRow,
      int startColumn,
      int unpaidLeaveRow,
      int totalUndertimeRow,
      ) {
    // Customer request calculation
    // ============================================================
    // Get the actual cells used for:
    // Unpaid Leave
    // Total Undertime

    final unpaidLeaveCell =
    sheet.getRangeByIndex(unpaidLeaveRow, 2);

    final totalUndertimeCell =
    sheet.getRangeByIndex(totalUndertimeRow, 2);

    final calculationCell =
    sheet.getRangeByIndex(startRow, startColumn);

    calculationCell
      ..formula =
          '=${unpaidLeaveCell.addressLocal}+${totalUndertimeCell.addressLocal}'
      ..numberFormat = '0.000'
      ..cellStyle.bold = true
      ..cellStyle.underline = true
      ..cellStyle.hAlign = HAlignType.center
      ..cellStyle.vAlign = VAlignType.center;

    // ============================================================
    // Leave / Holiday Colour Legend
    //
    // Legend starts one column after calculationCell
    //
    // Example:
    // calculationCell = E40
    //
    // E40 = calculation
    // F40 = A/L
    // G40 = U/L
    // H40 = PH
    // I40 = MC
    // ============================================================

    final legendItems = [
      {
        'label': 'A/L',
        'color': '#00B050',
      },
      {
        'label': 'U/L',
        'color': '#FF0000',
      },
      {
        'label': 'PH',
        'color': '#FFC000',
      },
      {
        'label': 'MC',
        'color': '#5B9BD5',
      },
    ];

    final int legendStartColumn = startColumn + 1;

    for (int i = 0; i < legendItems.length; i++) {
      final int column = legendStartColumn + i;

      // Colored cell
      final colorCell = sheet.getRangeByIndex(
        startRow,
        column,
      );

      colorCell
        ..setText('')
        ..cellStyle.backColor = legendItems[i]['color']!
        ..cellStyle.hAlign = HAlignType.center
        ..cellStyle.vAlign = VAlignType.center;

      // Label underneath
      final labelCell = sheet.getRangeByIndex(
        startRow + 1,
        column,
      );

      labelCell
        ..setText(legendItems[i]['label']!)
        ..cellStyle.bold = true
        ..cellStyle.hAlign = HAlignType.center
        ..cellStyle.vAlign = VAlignType.center;

      colorCell.columnWidth = 10;
    }

    // Deduction Total Advance
    sheet.getRangeByIndex(startRow + 6, startColumn + 5).setText("Deduction Total Advance:");

    final rmCell = sheet.getRangeByIndex(startRow + 7, startColumn + 5);

    rmCell
      ..setText("RM")
      ..cellStyle.bold = true
      ..cellStyle.hAlign = HAlignType.center
      ..cellStyle.vAlign = VAlignType.center;

    //Customer signature
    sheet.getRangeByIndex(startRow + 10, startColumn + 5).setText("Approved by :");
    sheet.getRangeByIndex(startRow + 10, startColumn + 6).setText("..............................................................");
    sheet.getRangeByIndex(startRow + 13, startColumn + 5).setText("Date :");
    sheet.getRangeByIndex(startRow + 13, startColumn + 6).setText("..............................................................");
  }
}