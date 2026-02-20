import 'package:flutter/material.dart';
import '../services/attendance_service.dart';
import '../services/date_service.dart';
import '../models/attendance_model.dart';

class ServicePortalAdminDeletePastDataPage extends StatefulWidget {
  const ServicePortalAdminDeletePastDataPage({super.key});

  @override
  State<ServicePortalAdminDeletePastDataPage> createState() =>
      _ServicePortalAdminDeletePastDataPageState();
}

class _ServicePortalAdminDeletePastDataPageState
    extends State<ServicePortalAdminDeletePastDataPage> {
  DateTime? selectedDate;
  bool isLoading = false;

  List<Attendance> attendances = []; // ✅ store all attendance for month

  final AttendanceService attendanceService = AttendanceService();

  // Month picker
  Future<void> _pickMonth() async {
    int selectedYear = DateTime.now().year;
    int selectedMonth = DateTime.now().month;

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Select Month"),
          content: Row(
            children: [
              Expanded(
                child: DropdownButton<int>(
                  value: selectedMonth,
                  isExpanded: true,
                  items: List.generate(12, (index) {
                    final month = index + 1;
                    return DropdownMenuItem(
                      value: month,
                      child: Text(month.toString().padLeft(2, '0')),
                    );
                  }),
                  onChanged: (value) {
                    selectedMonth = value!;
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: DropdownButton<int>(
                  value: selectedYear,
                  isExpanded: true,
                  items: List.generate(10, (index) {
                    final year = DateTime.now().year - index;
                    return DropdownMenuItem(
                      value: year,
                      child: Text(year.toString()),
                    );
                  }),
                  onChanged: (value) {
                    selectedYear = value!;
                  },
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel"),
            ),
            TextButton(
              onPressed: () {
                setState(() {
                  selectedDate = DateTime(selectedYear, selectedMonth);
                });
                Navigator.pop(context);
                _fetchMonthAttendance(); // ✅ fetch after selection
              },
              child: const Text("Confirm"),
            ),
          ],
        );
      },
    );
  }

  // Fetch all attendance for the selected month
  Future<void> _fetchMonthAttendance() async {
    if (selectedDate == null) return;

    setState(() {
      isLoading = true;
      attendances = [];
    });

    final year = selectedDate!.year;
    final month = selectedDate!.month;
    final startDate = DateTime(year, month, 1);
    final endDate = DateTime(year, month + 1, 0); // last day of month

    try {
      final data = await attendanceService.getAttendanceForAllUsers(
        startDate: startDate,
        endDate: endDate,
      );

      setState(() {
        attendances = data;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to fetch attendance: $e")),
      );
    }

    setState(() => isLoading = false);
  }

  // Delete all fetched attendance
  Future<void> _deletePastData() async {
    if (attendances.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("No attendance to delete")),
      );
      return;
    }

    setState(() => isLoading = true);

    try {
      for (var att in attendances) {
        await attendanceService.deleteAttendanceForAttendanceID(att.id);
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Past data deleted successfully")),
      );

      setState(() {
        attendances = [];
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error deleting data: $e")),
      );
    }

    setState(() => isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Delete Past Data")),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                ElevatedButton(
                  onPressed: _pickMonth,
                  child: Text(selectedDate == null
                      ? "Select Month"
                      : "${selectedDate!.year}-${selectedDate!.month.toString().padLeft(2, '0')}"),
                ),
                const SizedBox(height: 20),
                isLoading
                    ? const CircularProgressIndicator()
                    : Expanded(
                  child: attendances.isEmpty
                      ? const Text("No attendance found")
                      : ListView.builder(
                    itemCount: attendances.length,
                    itemBuilder: (context, index) {
                      final att = attendances[index];
                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        child: ListTile(
                          title: Text(att.userRef.id),
                          subtitle: Text(att.date),
                          trailing: Text(
                            att.scanIns
                                .map((s) =>
                                DateService.toDisplayTime(s.time))
                                .join(" | ") +
                                " | " +
                                att.scanOuts
                                    .map((s) =>
                                    DateService.toDisplayTime(s.time))
                                    .join(" | "),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _deletePastData,
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                  child: const Text("Delete Past Records"),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}