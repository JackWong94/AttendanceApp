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

    final usersToLoad =
    selectedUserId != null ? [selectedUserId!] : userNames.keys.toList();

    // Fetch attendance for each user
    for (var userId in usersToLoad) {
      final userRef = usersRef.doc(userId);

      QuerySnapshot<Map<String, dynamic>> snapshot;

      if (selectedFilter == FilterType.day) {
        // Day filter: exact date
        String dayStr = DateService.toStorageDate(selectedDate);
        snapshot = await attendanceRef
            .where('user', isEqualTo: userRef)
            .where('date', isEqualTo: dayStr)
            .get();
      } else {
        // Month filter: query whole month
        final startOfMonth = DateTime(selectedDate.year, selectedDate.month, 1);
        final endOfMonth =
        DateTime(selectedDate.year, selectedDate.month + 1, 0);
        snapshot = await attendanceRef
            .where('user', isEqualTo: userRef)
            .where('date',
            isGreaterThanOrEqualTo:
            DateService.toStorageDate(startOfMonth))
            .where('date',
            isLessThanOrEqualTo: DateService.toStorageDate(endOfMonth))
            .get();
      }

      // Map results to attendanceMap
      for (var doc in snapshot.docs) {
        final data = doc.data();
        String dateStr = data['date'] ?? '';
        String scanIn = '';
        String scanOut = '';

        if (data['scanIn'] != null) {
          scanIn = DateService.toDisplayTime(
              (data['scanIn'] as Timestamp).toDate());
        }
        if (data['scanOut'] != null) {
          scanOut = DateService.toDisplayTime(
              (data['scanOut'] as Timestamp).toDate());
        }

        attendanceMap[userId] ??= {};
        attendanceMap[userId]![dateStr] = {
          'scanIn': scanIn,
          'scanOut': scanOut,
          'name': userNames[userId]!,
        };
      }
    }

    setState(() {
      loading = false;
    });
  }

  Future<void> _exportExcel() async {
    final excel = Excel.createExcel();
    final usersToExport =
    selectedUserId != null ? [selectedUserId!] : attendanceMap.keys.toList();

    // Remove default empty sheet
    excel.delete('Sheet1');

    for (var uid in usersToExport) {
      final sheetName = userNames[uid] ?? uid;
      final sheet = excel[sheetName];

      sheet.appendRow(['Date', 'Clock In', 'Clock Out']);

      final dates = attendanceMap[uid]?.keys.toList() ?? [];
      dates.sort();

      for (var date in dates) {
        final scanIn = attendanceMap[uid]?[date]?['scanIn'] ?? '';
        final scanOut = attendanceMap[uid]?[date]?['scanOut'] ?? '';
        sheet.appendRow([date, scanIn, scanOut]);
      }
    }

    final fileBytes = excel.encode();
    final blob = html.Blob([fileBytes]);
    final url = html.Url.createObjectUrlFromBlob(blob);
    final anchor = html.AnchorElement(href: url)
      ..setAttribute('download', 'attendance.xlsx')
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
      // Proper month picker
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
          : Column(
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
                      onChanged: (val) => setState(() {
                        selectedUserId = val;
                      }),
                    );
                  },
                ),
                ElevatedButton(
                    onPressed: _loadAttendance,
                    child: const Text("Refresh")),
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
        final scanIn = attendanceMap[uid]?[day]?['scanIn'] ?? '';
        final scanOut = attendanceMap[uid]?[day]?['scanOut'] ?? '';
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
