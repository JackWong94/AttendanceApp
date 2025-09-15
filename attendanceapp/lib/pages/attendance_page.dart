import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart'; // for 24h formatting
import 'dart:convert';
import 'dart:html' as html; // for CSV download on web
import 'package:csv/csv.dart';

class AttendancePage extends StatefulWidget {
  const AttendancePage({super.key});

  @override
  State<AttendancePage> createState() => _AttendancePageState();
}

class _AttendancePageState extends State<AttendancePage> {
  final usersRef = FirebaseFirestore.instance.collection('users');
  final attendanceRef = FirebaseFirestore.instance.collection('attendance');

  DateTime selectedDate = DateTime.now(); // default today

  Map<String, Map<String, String>> attendanceMap = {};

  @override
  void initState() {
    super.initState();
    _loadAttendance();
  }

  Future<void> _loadAttendance() async {
    final dateStr =
        "${selectedDate.year}-${selectedDate.month}-${selectedDate.day}";

    final userSnapshot = await usersRef.get();
    Map<String, Map<String, String>> tempMap = {};

    for (var userDoc in userSnapshot.docs) {
      final userRef = userDoc.reference;

      final attQuery = await attendanceRef
          .where('user', isEqualTo: userRef) // MUST match DocumentReference
          .where('date', isEqualTo: dateStr)
          .limit(1)
          .get();

      String scanIn = '';
      String scanOut = '';
      if (attQuery.docs.isNotEmpty) {
        final data = attQuery.docs.first.data() as Map<String, dynamic>;
        if (data['scanIn'] != null) {
          scanIn = DateFormat('HH:mm').format(
              (data['scanIn'] as Timestamp).toDate().toLocal());
        }
        if (data['scanOut'] != null) {
          scanOut = DateFormat('HH:mm').format(
              (data['scanOut'] as Timestamp).toDate().toLocal());
        }
      }

      tempMap[userDoc.id] = {'name': userDoc['name'] ?? userDoc.id, 'scanIn': scanIn, 'scanOut': scanOut};
    }

    setState(() {
      attendanceMap = tempMap;
    });
  }

  void _downloadCSV() {
    List<List<String>> csvData = [
      ['Name', 'Clock In', 'Clock Out'],
      ...attendanceMap.values.map((data) =>
      [data['name']!, data['scanIn']!, data['scanOut']!]),
    ];

    String csv = ListToCsvConverter().convert(csvData);

    final blob = html.Blob([csv], 'text/csv');
    final url = html.Url.createObjectUrlFromBlob(blob);
    final anchor = html.AnchorElement(href: url)
      ..setAttribute("download", "attendance_${selectedDate.toIso8601String()}.csv")
      ..click();
    html.Url.revokeObjectUrl(url);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Attendance")),
      body: Column(
        children: [
          // Date picker + CSV button
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: selectedDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now(),
                    );
                    if (picked != null) {
                      setState(() {
                        selectedDate = picked;
                      });
                      _loadAttendance();
                    }
                  },
                  child: Text(
                    "Date: ${DateFormat('yyyy-MM-dd').format(selectedDate)}",
                  ),
                ),
                const SizedBox(width: 16),
                ElevatedButton(
                  onPressed: _downloadCSV,
                  child: const Text("Download CSV"),
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.vertical,
              child: DataTable(
                columnSpacing: 50,
                columns: const [
                  DataColumn(label: Text("Name")),
                  DataColumn(label: Text("Clock In")),
                  DataColumn(label: Text("Clock Out")),
                ],
                rows: attendanceMap.values.map((data) {
                  return DataRow(cells: [
                    DataCell(Text(data['name']!)),
                    DataCell(Text(data['scanIn']!)),
                    DataCell(Text(data['scanOut']!)),
                  ]);
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
