import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:attendanceapp/models/user_model.dart';
import 'package:attendanceapp/models/attendance_model.dart';
import 'package:attendanceapp/services/attendance_service.dart';

class NonAdminPageCheckHolidayApplicationStatus extends StatefulWidget {
  final UserModel user;
  final AttendanceService _attendanceService = AttendanceService();

  NonAdminPageCheckHolidayApplicationStatus({
    super.key,
    required this.user,
  });

  @override
  State<NonAdminPageCheckHolidayApplicationStatus> createState() =>
      _NonAdminPageCheckHolidayApplicationStatusState();
}

class _NonAdminPageCheckHolidayApplicationStatusState
    extends State<NonAdminPageCheckHolidayApplicationStatus> {
  late Future<List<Attendance>> _attendanceFuture;
  DateTime _selectedMonth = DateTime.now();

  @override
  void initState() {
    super.initState();
    _loadAttendance();
  }

  void _loadAttendance() {
    _attendanceFuture =
        widget._attendanceService.getAllAttendanceForUser(widget.user.id);
  }

  /// 📅 Month picker
  Future<void> _pickMonth() async {
    int tempYear = _selectedMonth.year;
    int tempMonth = _selectedMonth.month;

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text(
            "Select Month & Year",
            textAlign: TextAlign.center,
          ),
          content: StatefulBuilder(
            builder: (context, setLocalState) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  /// Year picker
                  DropdownButton<int>(
                    value: tempYear,
                    isExpanded: true,
                    items: List.generate(10, (index) {
                      final year = DateTime.now().year - 5 + index;
                      return DropdownMenuItem(
                        value: year,
                        child: Text(year.toString()),
                      );
                    }),
                    onChanged: (value) {
                      if (value != null) {
                        setLocalState(() => tempYear = value);
                      }
                    },
                  ),

                  const SizedBox(height: 12),

                  /// Month picker
                  DropdownButton<int>(
                    value: tempMonth,
                    isExpanded: true,
                    items: List.generate(12, (index) {
                      final month = index + 1;
                      return DropdownMenuItem(
                        value: month,
                        child: Text(
                          DateFormat.MMMM().format(DateTime(0, month)),
                        ),
                      );
                    }),
                    onChanged: (value) {
                      if (value != null) {
                        setLocalState(() => tempMonth = value);
                      }
                    },
                  ),
                ],
              );
            },
          ),
          actionsAlignment: MainAxisAlignment.center,
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _selectedMonth = DateTime(tempYear, tempMonth);
                });
                Navigator.pop(context);
              },
              child: const Text("OK"),
            ),
          ],
        );
      },
    );
  }

  /// ✅ Holiday / Leave statuses
  bool _isHoliday(Status status) {
    return status == Status.AL_FullDay ||
        status == Status.AL_HalfDay ||
        status == Status.UL_FullDay ||
        status == Status.UL_HalfDay ||
        status == Status.PH_FullDay ||
        status == Status.PH_HalfDay ||
        status == Status.MC_FullDay ||
        status == Status.MC_HalfDay;
  }

  bool _isSameMonth(DateTime date) {
    return date.year == _selectedMonth.year &&
        date.month == _selectedMonth.month;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          "Holiday / Leave (${DateFormat('MMM yyyy').format(_selectedMonth)})",
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_month),
            onPressed: _pickMonth,
          ),
        ],
      ),
      body: FutureBuilder<List<Attendance>>(
        future: _attendanceFuture,
        builder: (context, snapshot) {
          /// 🔄 Loading
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          /// ❌ Error
          if (snapshot.hasError) {
            return Center(
              child: Text("Error: ${snapshot.error}"),
            );
          }

          /// 📭 No data
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text("No records found"));
          }

          /// 🎯 Filter by month + holiday/leave
          final holidays = snapshot.data!
              .where((a) =>
          _isHoliday(a.status) &&
              _isSameMonth(DateTime.parse(a.date)))
              .toList()
            ..sort((a, b) => a.date.compareTo(b.date));

          if (holidays.isEmpty) {
            return const Center(
              child: Text("No holiday / leave records for this month"),
            );
          }

          /// 📋 List UI
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: holidays.length,
            itemBuilder: (context, index) {
              final attendance = holidays[index];

              return Card(
                child: ListTile(
                  leading: const Icon(Icons.event),
                  title: Text(
                    DateFormat('yyyy-MM-dd')
                        .format(DateTime.parse(attendance.date)),
                  ),
                  subtitle: Text(attendance.status.name),
                  trailing: Text(
                    attendance.applicationStatus.name,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
