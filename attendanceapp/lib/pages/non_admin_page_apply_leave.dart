import 'package:flutter/material.dart';
import 'package:attendanceapp/models/user_model.dart';
import 'package:attendanceapp/models/attendance_model.dart';
import 'package:attendanceapp/services/attendance_model_service.dart';
import 'package:attendanceapp/services/notification_model_service.dart';
import 'package:attendanceapp/services/user_model_service.dart';
import 'package:intl/intl.dart';

class NonAdminPageApplyLeave extends StatefulWidget {
  final UserModel user;

  const NonAdminPageApplyLeave({super.key, required this.user});

  @override
  State<NonAdminPageApplyLeave> createState() => _NonAdminPageApplyLeaveState();
}

class _NonAdminPageApplyLeaveState extends State<NonAdminPageApplyLeave> {
  DateTime? _selectedDate;
  Status _selectedStatus = Status.AL_FullDay; // default
  final TextEditingController _remarkController = TextEditingController();

  bool _isSubmitting = false;

  /// Submit leave request
  Future<void> _submitLeave() async {
    if (_selectedDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select a date")),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    final dateStr =
        "${_selectedDate!.year}-${_selectedDate!.month.toString().padLeft(2, '0')}-${_selectedDate!.day.toString().padLeft(2, '0')}";

    try {
      final userRef = UserModelService.instance.getUserDocRef(widget.user.id);
      final attendanceId = '${dateStr}_${widget.user.id}';

      // 1️⃣ Create or update attendance status
      await AttendanceModelService.instance.setAttendanceStatus(
        userId: widget.user.id,
        date: dateStr,
        status: _selectedStatus,
        applicationStatus: ApplicationStatus.pending,
      );

      // 2️⃣ Create leave notification with remark
      await NotificationModelService.instance.createForLeaveApplication(
        attendanceId: attendanceId,
        status: _selectedStatus,
        leaveDate: _selectedDate,
        userRef: userRef,
        remark: _remarkController.text.isNotEmpty
            ? _remarkController.text
            : "No reason provided",
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Leave request submitted! Waiting for approval."),
        ),
      );

      // Clear form
      setState(() {
        _selectedDate = null;
        _selectedStatus = Status.AL_FullDay;
        _remarkController.clear();
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to submit leave: $e")),
      );
    } finally {
      setState(() => _isSubmitting = false);
    }
  }

  /// Pick a date with range restriction
  Future<void> _pickDate() async {
    final now = DateTime.now();
    final oneYearLater = DateTime(now.year + 1, now.month, now.day);

    final picked = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: now,
      lastDate: oneYearLater,
    );

    if (picked != null) setState(() => _selectedDate = picked);
  }

  @override
  void dispose() {
    _remarkController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Apply Leave")),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  "Apply Leave for ${widget.user.name}",
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 30),

                // Date picker
                TextButton(
                  onPressed: _pickDate,
                  child: Text(
                    _selectedDate == null
                        ? "Select Date"
                        : "Selected Date: ${DateFormat('yyyy-MM-dd').format(_selectedDate!)}",
                  ),
                ),
                const SizedBox(height: 20),

                // Status selector
                DropdownButtonFormField<Status>(
                  value: _selectedStatus,
                  decoration: const InputDecoration(
                    labelText: "Leave Type",
                    border: OutlineInputBorder(),
                  ),
                  items: Status.values
                      .where((s) =>
                  s.name.startsWith("AL") ||
                      s.name.startsWith("UL") ||
                      s.name.startsWith("MC"))
                      .map((status) => DropdownMenuItem(
                    value: status,
                    child: Text(status.name),
                  ))
                      .toList(),
                  onChanged: (status) {
                    if (status != null) setState(() => _selectedStatus = status);
                  },
                ),
                const SizedBox(height: 20),

                // Remark input
                TextFormField(
                  controller: _remarkController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: "Reason / Remark",
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 30),

                // Submit button
                ElevatedButton(
                  onPressed: _isSubmitting ? null : _submitLeave,
                  child: _isSubmitting
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text("Submit Leave"),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
