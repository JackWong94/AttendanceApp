import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:excel/excel.dart';
import 'dart:html' as html;
import 'package:month_picker_dialog/month_picker_dialog.dart';
import '../services/date_service.dart'; // ✅ use DateService

class AttendancePage extends StatefulWidget {
  const AttendancePage({super.key});

  @override
  State<AttendancePage> createState() => _AttendancePageState();
}

enum FilterType { day, month }

class _AttendancePageState extends State<AttendancePage> {
  final usersRef = FirebaseFirestore.instance.collection('users');
  final attendanceRef = FirebaseFirestore.instance.collection('attendance');

  DateTime selectedDate = DateTime.now();
  FilterType selectedFilter = FilterType.day;
  String? selectedUserId;

  // Map structure: { userId : { dateStr : { 'scanIn': ..., 'scanOut': ..., 'name': ... } } }
  Map<String, Map<String, Map<String, String>>> attendanceMap = {};
  Map<String, String> userNames = {};
  bool loading = false;

  @override
  void initState() {
    super.initState();
    _loadAttendance();
  }

  Future<void> _loadAttendance() async {
    setState(() {
      loading = true;
      attendanceMap.clear();
      userNames.clear();
    });

    // Load all users
    final usersSnapshot = await usersRef.get();
    for (var userDoc in usersSnapshot.docs) {
      userNames[userDoc.id] = userDoc['name'] ?? userDoc.id;
    }

    if (selectedFilter == FilterType.day) {
      await _loadDayAttendance();
    } else {
      await _loadMonthAttendance();
    }

    setState(() {
      loading = false;
    });
  }

  Future<void> _loadDayAttendance() async {
    final usersToLoad =
    selectedUserId != null ? [selectedUserId!] : userNames.keys.toList();

    final dayStr = DateService.toStorageDate(selectedDate);

    for (var userId in usersToLoad) {
      final userRef = usersRef.doc(userId);

      final snapshot = await attendanceRef
          .where('user', isEqualTo: userRef)
          .where('date', isEqualTo: dayStr)
          .get();

      if (snapshot.docs.isEmpty) {
        // ✅ No record for this day → put N/A
        attendanceMap[userId] ??= {};
        attendanceMap[userId]![dayStr] = {
          'scanIn': 'N/A',
          'scanOut': 'N/A',
          'name': userNames[userId]!,
        };
      }

      for (var doc in snapshot.docs) {
        final data = doc.data();
        String scanIn = data['scanIn'] != null
            ? DateService.toDisplayTime((data['scanIn'] as Timestamp).toDate())
            : 'N/A';
        String scanOut = data['scanOut'] != null
            ? DateService.toDisplayTime((data['scanOut'] as Timestamp).toDate())
            : 'N/A';

        attendanceMap[userId] ??= {};
        attendanceMap[userId]![dayStr] = {
          'scanIn': scanIn,
          'scanOut': scanOut,
          'name': userNames[userId]!,
        };
      }
    }
  }

  Future<void> _loadMonthAttendance() async {
    final usersToLoad =
    selectedUserId != null ? [selectedUserId!] : userNames.keys.toList();

    int totalDays =
    DateUtils.getDaysInMonth(selectedDate.year, selectedDate.month);

    for (int i = 1; i <= totalDays; i++) {
      final date = DateTime(selectedDate.year, selectedDate.month, i);
      final formatted = DateService.toStorageDate(date);

      for (var userId in usersToLoad) {
        final userRef = usersRef.doc(userId);

        final snapshot = await attendanceRef
            .where('user', isEqualTo: userRef)
            .where('date', isEqualTo: formatted)
            .get();

        if (snapshot.docs.isEmpty) {
          // ✅ No record for this day → put N/A
          attendanceMap[userId] ??= {};
          attendanceMap[userId]![formatted] = {
            'scanIn': 'N/A',
            'scanOut': 'N/A',
            'name': userNames[userId]!,
          };
        }

        for (var doc in snapshot.docs) {
          final data = doc.data();
          String scanIn = data['scanIn'] != null
              ? DateService.toDisplayTime(
              (data['scanIn'] as Timestamp).toDate())
              : 'N/A';
          String scanOut = data['scanOut'] != null
              ? DateService.toDisplayTime(
              (data['scanOut'] as Timestamp).toDate())
              : 'N/A';

          attendanceMap[userId] ??= {};
          attendanceMap[userId]![formatted] = {
            'scanIn': scanIn,
            'scanOut': scanOut,
            'name': userNames[userId]!,
          };
        }
      }
    }
  }

  Future<void> _exportExcel() async {
    setState(() => loading = true);
    await _loadAttendance(); // ✅ fetch fresh data
    setState(() => loading = false);

    final excel = Excel.createExcel();
    final usersToExport =
    selectedUserId != null ? [selectedUserId!] : attendanceMap.keys.toList();

    excel.delete('Sheet1'); // remove default

    for (var uid in usersToExport) {
      final sheetName = userNames[uid] ?? uid;
      final sheet = excel[sheetName];
      sheet.appendRow(['Date', 'Clock In', 'Clock Out']);

      List<String> dates = [];
      if (selectedFilter == FilterType.day) {
        dates = [DateService.toStorageDate(selectedDate)];
      } else {
        int totalDays =
        DateUtils.getDaysInMonth(selectedDate.year, selectedDate.month);
        for (int i = 1; i <= totalDays; i++) {
          dates.add(DateService.toStorageDate(
              DateTime(selectedDate.year, selectedDate.month, i)));
        }
      }

      for (var date in dates) {
        final scanIn = attendanceMap[uid]?[date]?['scanIn'] ?? 'N/A';
        final scanOut = attendanceMap[uid]?[date]?['scanOut'] ?? 'N/A';
        sheet.appendRow([date, scanIn, scanOut]);
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
      if (picked != null) {
        setState(() => selectedDate = picked);
      }
    } else {
      final picked = await showMonthPicker(
        context: context,
        initialDate: selectedDate,
        firstDate: DateTime(2020),
        lastDate: DateTime.now(),
      );
      if (picked != null) {
        setState(() => selectedDate = picked);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Attendance")),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : Center( // ✅ center the whole page
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Wrap(
                spacing: 16,
                runSpacing: 16,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  DropdownButton<FilterType>(
                    value: selectedFilter,
                    items: const [
                      DropdownMenuItem(
                          value: FilterType.day, child: Text("Day")),
                      DropdownMenuItem(
                          value: FilterType.month, child: Text("Month")),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setState(() => selectedFilter = val);
                      }
                    },
                  ),
                  ElevatedButton(
                    onPressed: _pickDateOrMonth,
                    child: Text(selectedFilter == FilterType.day
                        ? DateService.toStorageDate(selectedDate)
                        : DateService.toMonthString(selectedDate)),
                  ),
                  FutureBuilder(
                    future: usersRef.get(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState ==
                          ConnectionState.waiting) {
                        return const CircularProgressIndicator();
                      }
                      final docs = snapshot.data?.docs ?? [];
                      return DropdownButton<String>(
                        value: selectedUserId,
                        hint: const Text("All Users"),
                        items: [
                          const DropdownMenuItem(
                              value: null, child: Text("All Users")),
                          ...docs.map((doc) => DropdownMenuItem(
                            value: doc.id,
                            child: Text(doc['name'] ?? doc.id),
                          ))
                        ],
                        onChanged: (val) =>
                            setState(() => selectedUserId = val),
                      );
                    },
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
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.vertical,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: _buildTableWidgets(),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildTableWidgets() {
    List<Widget> widgets = [];

    List<String> days = [];
    if (selectedFilter == FilterType.day) {
      days = [DateService.toStorageDate(selectedDate)];
    } else {
      int totalDays =
      DateUtils.getDaysInMonth(selectedDate.year, selectedDate.month);
      for (int i = 1; i <= totalDays; i++) {
        days.add(DateService.toStorageDate(
            DateTime(selectedDate.year, selectedDate.month, i)));
      }
    }

    final usersToShow =
    selectedUserId != null ? [selectedUserId!] : userNames.keys.toList();

    for (var day in days) {
      widgets.add(Padding(
        padding: const EdgeInsets.only(top: 16, bottom: 4),
        child: Text(
          day,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
      ));

      for (var uid in usersToShow) {
        final scanIn = attendanceMap[uid]?[day]?['scanIn'] ?? 'N/A';
        final scanOut = attendanceMap[uid]?[day]?['scanOut'] ?? 'N/A';
        widgets.add(Row(
          children: [
            SizedBox(
                width: 200,
                child: Text(userNames[uid] ?? uid,
                    softWrap: true, style: const TextStyle(fontSize: 14))),
            const SizedBox(width: 16),
            SizedBox(width: 80, child: Text(scanIn)),
            SizedBox(width: 80, child: Text(scanOut)),
          ],
        ));
      }
    }

    return widgets;
  }
}
