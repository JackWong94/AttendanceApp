import 'package:flutter/material.dart';
import 'package:excel/excel.dart';
import 'dart:html' as html;
import 'package:month_picker_dialog/month_picker_dialog.dart';
import '../services/date_service.dart';
import '../services/user_model_service.dart';
import '../services/attendance_model_service.dart';
import '../services/attendance_service.dart';
import '../models/user_model.dart';

enum FilterType { day, month }

class AttendancePage extends StatefulWidget {
  const AttendancePage({super.key});

  @override
  State<AttendancePage> createState() => _AttendancePageState();
}

class _AttendancePageState extends State<AttendancePage> {
  final AttendanceService _attendanceService = AttendanceService();

  DateTime selectedDate = DateTime.now();
  FilterType selectedFilter = FilterType.day;
  String? selectedUserId;

  Map<String, Map<String, String>> attendanceMap = {}; // {userId: {date: "normalIn|lunchOut|lunchIn|normalOut|otIn|otOut"}}
  Map<String, String> userNames = {}; // {userId: userName}

  bool loading = false;

  @override
  void initState() {
    super.initState();
    _initUsersAndAttendance();
  }

  Future<void> _initUsersAndAttendance() async {
    setState(() {
      loading = true;
      attendanceMap.clear();
      userNames.clear();
    });

    final users = await UserModelService.instance.getAllUsers();
    for (var user in users) {
      userNames[user.id] = user.name;
    }

    await _loadAttendance();

    setState(() {
      loading = false;
    });
  }

  Future<void> _loadAttendance() async {
    setState(() => loading = true);

    final startOfMonth = DateTime(selectedDate.year, selectedDate.month, 1);
    final endOfMonth = DateTime(
      selectedDate.year,
      selectedDate.month,
      DateService.getDaysInMonth(selectedDate.year, selectedDate.month),
    );

    Map<String, Map<String, String>> newMap = {};

    if (selectedFilter == FilterType.day) {
      final dateStr = DateService.toStorageDate(selectedDate);

      for (var userId in userNames.keys) {
        final user = await UserModelService.instance.getUserById(userId);
        if (user == null) continue;

        final record = await _attendanceService.fetchAttendance(user: user, date: dateStr);
        newMap[userId] = {
          dateStr:
          '${record['normalIn'] ?? 'N/A'}|${record['lunchOut'] ?? 'N/A'}|${record['lunchIn'] ?? 'N/A'}|${record['normalOut'] ?? 'N/A'}|${record['otIn'] ?? 'N/A'}|${record['otOut'] ?? 'N/A'}',
        };
      }
    } else {
      final allAttendances = await AttendanceModelService.instance
          .fetchAttendanceForMonthAllUsers(startDate: startOfMonth, endDate: endOfMonth);

      for (var uid in userNames.keys) {
        newMap[uid] = {};
        for (int i = 1; i <= DateService.getDaysInMonth(selectedDate.year, selectedDate.month); i++) {
          final day = DateTime(selectedDate.year, selectedDate.month, i);
          newMap[uid]![DateService.toStorageDate(day)] = 'N/A|N/A|N/A|N/A|N/A|N/A';
        }
      }

      for (var att in allAttendances) {
        final uid = att.userRef.id;
        if (!newMap.containsKey(uid)) continue;

        final ams = AttendanceModelService.instance;

        newMap[uid]![att.date] =
        '${ams.getScanInByType(att, ScanType.normal) != null ? DateService.toDisplayTime(ams.getScanInByType(att, ScanType.normal)!) : 'N/A'}|'
            '${ams.getScanOutByType(att, ScanType.lunch) != null ? DateService.toDisplayTime(ams.getScanOutByType(att, ScanType.lunch)!) : 'N/A'}|'
            '${ams.getScanInByType(att, ScanType.lunch) != null ? DateService.toDisplayTime(ams.getScanInByType(att, ScanType.lunch)!) : 'N/A'}|'
            '${ams.getScanOutByType(att, ScanType.normal) != null ? DateService.toDisplayTime(ams.getScanOutByType(att, ScanType.normal)!) : 'N/A'}|'
            '${ams.getScanInByType(att, ScanType.ot) != null ? DateService.toDisplayTime(ams.getScanInByType(att, ScanType.ot)!) : 'N/A'}|'
            '${ams.getScanOutByType(att, ScanType.ot) != null ? DateService.toDisplayTime(ams.getScanOutByType(att, ScanType.ot)!) : 'N/A'}';
      }
    }

    setState(() {
      attendanceMap = newMap;
      loading = false;
    });
  }

  Future<void> _exportExcel() async {
    setState(() => loading = true);
    await _loadAttendance();
    setState(() => loading = false);

    final excel = Excel.createExcel();
    excel.delete('Sheet1');

    final usersToExport = selectedUserId != null ? [selectedUserId!] : attendanceMap.keys.toList();

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
        selectedFilter == FilterType.day
            ? 'attendance-${DateService.toStorageDate(selectedDate)}.xlsx'
            : 'attendance-${DateService.toMonthString(selectedDate)}.xlsx',
      )
      ..click();
    html.Url.revokeObjectUrl(url);
  }

  Future<void> _pickDateOrMonth() async {
    if (selectedFilter == FilterType.day) {
      final picked = await showDatePicker(
        context: context,
        initialDate: selectedDate,
        firstDate: DateTime(2020),
        lastDate: DateTime.now(),
      );
      if (picked != null) setState(() => selectedDate = picked);
    } else {
      final picked = await showMonthPicker(
        context: context,
        initialDate: selectedDate,
        firstDate: DateTime(2020),
        lastDate: DateTime.now(),
      );
      if (picked != null) setState(() => selectedDate = picked);
    }
    await _loadAttendance();
  }

  @override
  Widget build(BuildContext context) {
    final sortedDates = attendanceMap.values
        .expand((map) => map.keys)
        .toSet()
        .toList()
      ..sort();

    return Scaffold(
      appBar: AppBar(title: const Text("Attendance")),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1000),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Filters
              Padding(
                padding: const EdgeInsets.all(16),
                child: Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  alignment: WrapAlignment.center,
                  children: [
                    DropdownButton<FilterType>(
                      value: selectedFilter,
                      items: const [
                        DropdownMenuItem(value: FilterType.day, child: Text("Day")),
                        DropdownMenuItem(value: FilterType.month, child: Text("Month")),
                      ],
                      onChanged: (val) async {
                        if (val != null) setState(() => selectedFilter = val);
                        await _loadAttendance();
                      },
                    ),
                    ElevatedButton(
                      onPressed: _pickDateOrMonth,
                      child: Text(selectedFilter == FilterType.day
                          ? DateService.toStorageDate(selectedDate)
                          : DateService.toMonthString(selectedDate)),
                    ),
                    DropdownButton<String>(
                      value: selectedUserId,
                      hint: const Text("All Users"),
                      items: [
                        const DropdownMenuItem(value: null, child: Text("All Users")),
                        ...userNames.entries.map((e) => DropdownMenuItem(
                          value: e.key,
                          child: Text(e.value),
                        )),
                      ],
                      onChanged: (val) => setState(() => selectedUserId = val),
                    ),
                    ElevatedButton(onPressed: _loadAttendance, child: const Text("Update")),
                    ElevatedButton(onPressed: _exportExcel, child: const Text("Export Excel")),
                  ],
                ),
              ),

              // Table
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.vertical,
                  child: Column(
                    children: selectedFilter == FilterType.day
                        ? [_buildDayTable()]
                        : sortedDates.map((d) => _buildMonthTable(d)).toList(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDayTable() {
    final date = DateService.toStorageDate(selectedDate);
    final usersToShow = selectedUserId != null ? [selectedUserId!] : userNames.keys.toList();

    return Card(
      margin: const EdgeInsets.all(16),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columns: const [
            DataColumn(label: Text('User', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Normal In', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Lunch Out', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Lunch In', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Normal Out', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('OT In', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('OT Out', style: TextStyle(fontWeight: FontWeight.bold))),
          ],
          rows: usersToShow.map((uid) {
            final record = attendanceMap[uid]?[date]?.split('|') ??
                ['N/A', 'N/A', 'N/A', 'N/A', 'N/A', 'N/A'];
            return DataRow(cells: [
              DataCell(Text(userNames[uid]!)),
              DataCell(Text(record[0])),
              DataCell(Text(record[1])),
              DataCell(Text(record[2])),
              DataCell(Text(record[3])),
              DataCell(Text(record[4])),
              DataCell(Text(record[5])),
            ]);
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildMonthTable(String date) {
    final usersToShow = selectedUserId != null ? [selectedUserId!] : userNames.keys.toList();

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(date, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: const [
                  DataColumn(label: Text('User', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Normal In', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Lunch Out', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Lunch In', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Normal Out', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('OT In', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('OT Out', style: TextStyle(fontWeight: FontWeight.bold))),
                ],
                rows: usersToShow.map((uid) {
                  final record = attendanceMap[uid]?[date]?.split('|') ??
                      ['N/A', 'N/A', 'N/A', 'N/A', 'N/A', 'N/A'];
                  return DataRow(cells: [
                    DataCell(Text(userNames[uid]!)),
                    DataCell(Text(record[0])),
                    DataCell(Text(record[1])),
                    DataCell(Text(record[2])),
                    DataCell(Text(record[3])),
                    DataCell(Text(record[4])),
                    DataCell(Text(record[5])),
                  ]);
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
