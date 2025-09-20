import 'package:flutter/material.dart';
import 'package:excel/excel.dart';
import 'dart:html' as html;
import 'package:month_picker_dialog/month_picker_dialog.dart';
import '../services/date_service.dart';
import '../services/user_model_service.dart';
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

  Map<String, Map<String, String>> attendanceMap = {}; // {userId: {date: {scanIn/scanOut}}}
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

    // Load all users via UserModelService
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

    final usersToLoad = selectedUserId != null
        ? [selectedUserId!]
        : userNames.keys.toList();

    Map<String, Map<String, String>> newMap = {};

    for (var userId in usersToLoad) {
      final user = await UserModelService.instance.getUserById(userId);
      if (user == null) continue;

      if (selectedFilter == FilterType.day) {
        final dateStr = DateService.toStorageDate(selectedDate);
        final record =
        await _attendanceService.fetchAttendance(user: user, date: dateStr);
        newMap[userId] = {
          dateStr: record.isNotEmpty ? record['scanIn']! + '|' + record['scanOut']! : 'N/A|N/A'
        };
      } else {
        final monthRecords =
        await _attendanceService.fetchMonthlyAttendance(user: user, month: selectedDate);
        for (var entry in monthRecords.entries) {
          newMap[userId] ??= {};
          newMap[userId]![entry.key] =
              entry.value['scanIn']! + '|' + entry.value['scanOut']!;
        }
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

    final usersToExport = selectedUserId != null
        ? [selectedUserId!]
        : attendanceMap.keys.toList();

    for (var uid in usersToExport) {
      final sheetName = userNames[uid] ?? uid;
      final sheet = excel[sheetName];
      sheet.appendRow(['Date', 'Clock In', 'Clock Out']);

      final days = attendanceMap[uid]?.keys.toList() ?? [];
      for (var day in days) {
        final split = attendanceMap[uid]![day]!.split('|');
        sheet.appendRow([day, split[0], split[1]]);
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
              : 'attendance-${DateService.toMonthString(selectedDate)}.xlsx')
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
    return Scaffold(
      appBar: AppBar(title: const Text("Attendance")),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        scrollDirection: Axis.vertical,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center, // ✅ Center horizontally
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Wrap(
                      spacing: 16,
                      runSpacing: 16,
                      children: [
                        DropdownButton<FilterType>(
                          value: selectedFilter,
                          items: const [
                            DropdownMenuItem(value: FilterType.day, child: Text("Day")),
                            DropdownMenuItem(value: FilterType.month, child: Text("Month")),
                          ],
                          onChanged: (val) {
                            if (val != null) setState(() => selectedFilter = val);
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
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: _buildTable(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }


  List<Widget> _buildTable() {
    List<Widget> widgets = [];
    final days = selectedFilter == FilterType.day
        ? [DateService.toStorageDate(selectedDate)]
        : attendanceMap.values
        .expand((map) => map.keys)
        .toSet()
        .toList()
      ..sort();

    final usersToShow = selectedUserId != null ? [selectedUserId!] : userNames.keys.toList();

    for (var day in days) {
      widgets.add(Padding(
        padding: const EdgeInsets.only(top: 16, bottom: 4),
        child: Text(day, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
      ));

      for (var uid in usersToShow) {
        final record = attendanceMap[uid]?[day]?.split('|') ?? ['N/A', 'N/A'];
        widgets.add(Row(
          children: [
            SizedBox(width: 200, child: Text(userNames[uid] ?? uid)),
            const SizedBox(width: 16),
            SizedBox(width: 80, child: Text(record[0])),
            SizedBox(width: 80, child: Text(record[1])),
          ],
        ));
      }
    }

    return widgets;
  }
}
