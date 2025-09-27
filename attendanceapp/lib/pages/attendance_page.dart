import 'package:flutter/material.dart';
import 'package:excel/excel.dart';
import 'dart:html' as html;
import 'package:month_picker_dialog/month_picker_dialog.dart';
import '../services/date_service.dart';
import '../services/user_model_service.dart';
import '../services/attendance_model_service.dart';
import '../services/attendance_service.dart';
import '../models/attendance_model.dart';
import '../services/export_excel_service.dart';

enum FilterType { day, month }

// ✅ Single source of truth for number of scan pairs
const int maxScans = 3; // means ScanIn1–3, ScanOut1–3

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

  // {userId: {date: "in1|out1|in2|out2|..."}}
  Map<String, Map<String, String>> attendanceMap = {};
  Map<String, String> userNames = {};

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

    // Initialize map for all users
    for (var uid in userNames.keys) {
      newMap[uid] = {};
      int days = DateService.getDaysInMonth(selectedDate.year, selectedDate.month);
      for (int i = 1; i <= days; i++) {
        final day = DateTime(selectedDate.year, selectedDate.month, i);

        // Fill N/A for all scans (in/out pairs)
        newMap[uid]![DateService.toStorageDate(day)] =
            List.filled(maxScans * 2, 'N/A').join('|');
      }
    }

    // Fetch attendances
    List<Attendance> allAttendances;
    if (selectedFilter == FilterType.day) {
      allAttendances = [];
      final dateStr = DateService.toStorageDate(selectedDate);
      for (var uid in userNames.keys) {
        final record = await AttendanceModelService.instance.fetchAttendanceForDate(
          userId: uid,
          date: dateStr,
        );
        if (record != null) allAttendances.add(record);
      }
    } else {
      allAttendances = await AttendanceModelService.instance
          .fetchAttendanceForMonthAllUsers(startDate: startOfMonth, endDate: endOfMonth);
    }

    // Fill in actual data
    for (var att in allAttendances) {
      final uid = att.userRef.id;
      if (!newMap.containsKey(uid)) continue;

      final ins = List.generate(
        maxScans,
            (i) => att.scanIns.length > i
            ? DateService.toDisplayTime(att.scanIns[i].time)
            : 'N/A',
      );
      final outs = List.generate(
        maxScans,
            (i) => att.scanOuts.length > i
            ? DateService.toDisplayTime(att.scanOuts[i].time)
            : 'N/A',
      );

      // Pack into string (in/out pairs)
      List<String> all = [];
      for (int i = 0; i < maxScans; i++) {
        all.add(ins[i]);
        all.add(outs[i]);
      }

      newMap[uid]![att.date] = all.join('|');
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

    if (selectedFilter == FilterType.day) {
      ExportExcelService.exportDayAttendance(
        attendanceMap: attendanceMap,
        userNames: userNames,
        selectedDate: selectedDate,
        selectedUserId: selectedUserId,
      );
    } else {
      ExportExcelService.exportMonthAttendance(
        attendanceMap: attendanceMap,
        userNames: userNames,
        selectedDate: selectedDate,
        selectedUserId: selectedUserId,
      );
    }
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
                        DropdownMenuItem(
                            value: FilterType.day, child: Text("Day")),
                        DropdownMenuItem(
                            value: FilterType.month, child: Text("Month")),
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
                    DropdownButton<String?>(
                      value: selectedUserId,
                      hint: const Text("All Users"),
                      items: [
                        const DropdownMenuItem<String?>(
                            value: null, child: Text("All Users")),
                        ...userNames.entries.map((e) => DropdownMenuItem(
                          value: e.key,
                          child: Text(e.value),
                        )),
                      ],
                      onChanged: (val) =>
                          setState(() => selectedUserId = val),
                    ),
                    ElevatedButton(
                        onPressed: _loadAttendance,
                        child: const Text("Update")),
                    ElevatedButton(
                        onPressed: _exportExcel,
                        child: const Text("Export Excel")),
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
    final usersToShow =
    selectedUserId != null ? [selectedUserId!] : userNames.keys.toList();

    return Card(
      margin: const EdgeInsets.all(16),
      child: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columns: [
                const DataColumn(
                    label: Text('User',
                        style: TextStyle(fontWeight: FontWeight.bold))),
                for (int i = 0; i < maxScans; i++) ...[
                  DataColumn(
                      label: Text('Scan In ${i + 1}',
                          style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(
                      label: Text('Scan Out ${i + 1}',
                          style: TextStyle(fontWeight: FontWeight.bold))),
                ],
              ],
              rows: usersToShow.map((uid) {
                final record = attendanceMap[uid]?[date]?.split('|') ??
                    List.filled(maxScans * 2, 'N/A');
                return DataRow(cells: [
                  DataCell(
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: constraints.maxWidth * 0.15, // ✅ relative to table
                      ),
                      child: Text(
                        userNames[uid]!,
                        softWrap: true,
                        overflow: TextOverflow.visible,
                      ),
                    ),
                  ),
                  for (var val in record) DataCell(Text(val)),
                ]);
              }).toList(),
            ),
          );
        },
      ),
    );
  }

  Widget _buildMonthTable(String date) {
    final usersToShow =
    selectedUserId != null ? [selectedUserId!] : userNames.keys.toList();

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(date,
                style: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),
            LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    columns: [
                      const DataColumn(
                          label: Text('User',
                              style: TextStyle(fontWeight: FontWeight.bold))),
                      for (int i = 0; i < maxScans; i++) ...[
                        DataColumn(
                            label: Text('Scan In ${i + 1}',
                                style:
                                TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(
                            label: Text('Scan Out ${i + 1}',
                                style:
                                TextStyle(fontWeight: FontWeight.bold))),
                      ],
                    ],
                    rows: usersToShow.map((uid) {
                      final record = attendanceMap[uid]?[date]?.split('|') ??
                          List.filled(maxScans * 2, 'N/A');
                      return DataRow(cells: [
                        DataCell(
                          ConstrainedBox(
                            constraints: BoxConstraints(
                              maxWidth:
                              constraints.maxWidth * 0.15, // ✅ relative
                            ),
                            child: Text(
                              userNames[uid]!,
                              softWrap: true,
                              overflow: TextOverflow.visible,
                            ),
                          ),
                        ),
                        for (var val in record) DataCell(Text(val)),
                      ]);
                    }).toList(),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

}
