import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:excel/excel.dart';
import 'dart:html' as html;

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

    List<DateTime> daysToLoad = [];
    if (selectedFilter == FilterType.day) {
      daysToLoad = [selectedDate];
    } else {
      int totalDays = DateUtils.getDaysInMonth(selectedDate.year, selectedDate.month);
      for (int i = 1; i <= totalDays; i++) {
        daysToLoad.add(DateTime(selectedDate.year, selectedDate.month, i));
      }
    }

    final usersToLoad =
    selectedUserId != null ? [selectedUserId!] : userNames.keys.toList();

    // Fetch attendance for each user for each day
    for (var day in daysToLoad) {
      String dayStr = DateFormat('yyyy-M-d').format(day);
      for (var userId in usersToLoad) {
        final userRef = usersRef.doc(userId);
        final attQuery = await attendanceRef
            .where('date', isEqualTo: dayStr)
            .where('user', isEqualTo: userRef)
            .limit(1)
            .get();
        for (var doc in attQuery.docs) {
          final data = doc.data();
          print("Firestore document ID: ${doc.id}");
          print("User: ${data['user']}");
          print("Date stored in Firestore: ${data['date']}");
          print("Scan In: ${data['scanIn']}, Scan Out: ${data['scanOut']}");
        }
        String scanIn = '';
        String scanOut = '';

        if (attQuery.docs.isNotEmpty) {
          final data = attQuery.docs.first.data() as Map<String, dynamic>;
          if (data['scanIn'] != null) {
            scanIn = DateFormat('HH:mm').format((data['scanIn'] as Timestamp).toDate());
          }
          if (data['scanOut'] != null) {
            scanOut = DateFormat('HH:mm').format((data['scanOut'] as Timestamp).toDate());
          }
        }

        attendanceMap[userId] ??= {};
        attendanceMap[userId]![dayStr] = {
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
      // Month picker workaround: pick first day of month
      final picked = await showDatePicker(
        context: context,
        initialDate: selectedDate,
        firstDate: DateTime(2020),
        lastDate: DateTime.now(),
        selectableDayPredicate: (day) => day.day == 1,
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
                    DropdownMenuItem(value: FilterType.day, child: Text("Day")),
                    DropdownMenuItem(value: FilterType.month, child: Text("Month")),
                  ],
                  onChanged: (val) {
                    if (val != null) setState(() => selectedFilter = val);
                  },
                ),
                ElevatedButton(
                  onPressed: _pickDateOrMonth,
                  child: Text(DateFormat(
                      selectedFilter == FilterType.day ? 'yyyy-M-d' : 'yyyy-M')
                      .format(selectedDate)),
                ),
                FutureBuilder(
                  future: usersRef.get(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const CircularProgressIndicator();
                    }
                    final docs = snapshot.data?.docs ?? [];
                    return DropdownButton<String>(
                      value: selectedUserId,
                      hint: const Text("All Users"),
                      items: [
                        const DropdownMenuItem(value: null, child: Text("All Users")),
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
                ElevatedButton(onPressed: _loadAttendance, child: const Text("Refresh")),
                ElevatedButton(onPressed: _exportExcel, child: const Text("Export Excel")),
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
      days = [DateFormat('yyyy-M-d').format(selectedDate)];
    } else {
      int totalDays = DateUtils.getDaysInMonth(selectedDate.year, selectedDate.month);
      for (int i = 1; i <= totalDays; i++) {
        days.add(DateFormat('yyyy-M-d')
            .format(DateTime(selectedDate.year, selectedDate.month, i)));
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
