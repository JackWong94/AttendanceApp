import 'package:flutter/material.dart';
import '../services/attendance_service.dart';
import '../services/date_service.dart';
import '../models/attendance_model.dart';
import '../services/notification_model_service.dart';
import '../services/image_model_service.dart';
import '../models/notification_model.dart';

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

  int selectedYear = DateTime.now().year;
  int selectedMonth = DateTime.now().month;

  List<Attendance> attendances = [];
  List<NotificationModel> notifications = [];
  List<String> attendancePhotoDocs = [];

  final AttendanceService attendanceService = AttendanceService();
  final ImageModelService imageService = ImageModelService.instance;
  final NotificationModelService notificationService = NotificationModelService.instance;

  // -----------------------------
  // Month picker
  // -----------------------------
  Future<void> _pickMonth() async {
    int tempYear = selectedYear;
    int tempMonth = selectedMonth;

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text("Select Month"),
            content: Row(
              children: [
                Expanded(
                  child: DropdownButton<int>(
                    value: tempMonth,
                    isExpanded: true,
                    items: List.generate(12, (index) => index + 1)
                        .map((m) => DropdownMenuItem(value: m, child: Text(m.toString().padLeft(2,'0'))))
                        .toList(),
                    onChanged: (value) => setDialogState(() => tempMonth = value!),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: DropdownButton<int>(
                    value: tempYear,
                    isExpanded: true,
                    items: List.generate(10, (index) => DateTime.now().year - index)
                        .map((y) => DropdownMenuItem(value: y, child: Text(y.toString())))
                        .toList(),
                    onChanged: (value) => setDialogState(() => tempYear = value!),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
              TextButton(
                onPressed: () {
                  setState(() {
                    selectedYear = tempYear;
                    selectedMonth = tempMonth;
                    selectedDate = DateTime(tempYear, tempMonth);
                  });
                  Navigator.pop(context);
                  _fetchMonthAttendance();
                  _fetchMonthNotifications();
                  _fetchMonthAttendancePhotos();
                },
                child: const Text("Confirm"),
              ),
            ],
          );
        });
      },
    );
  }

  // -----------------------------
  // Fetch attendance
  // -----------------------------
  Future<void> _fetchMonthAttendance() async {
    if (selectedDate == null) return;

    setState(() { isLoading = true; attendances = []; });

    final start = DateTime(selectedDate!.year, selectedDate!.month, 1);
    final end = DateTime(selectedDate!.year, selectedDate!.month + 1, 0);

    try {
      final data = await attendanceService.getAttendanceForAllUsers(startDate: start, endDate: end);
      setState(() => attendances = data);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Failed to fetch attendance: $e")));
    }

    setState(() => isLoading = false);
  }

  // -----------------------------
  // Fetch notifications
  // -----------------------------
  Future<void> _fetchMonthNotifications() async {
    if (selectedDate == null) return;

    setState(() { isLoading = true; notifications = []; });

    final start = DateTime(selectedDate!.year, selectedDate!.month, 1);
    final end = DateTime(selectedDate!.year, selectedDate!.month + 1, 0);

    try {
      final data = await notificationService.fetchBySafeDeleteDate(start: start, end: end);
      setState(() => notifications = data);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Failed to fetch notifications: $e")));
    }

    setState(() => isLoading = false);
  }

  // -----------------------------
  // Fetch attendance photos using ImageModelService
  // -----------------------------
  Future<void> _fetchMonthAttendancePhotos() async {
    if (selectedDate == null) return;

    setState(() { isLoading = true; attendancePhotoDocs = []; });

    final start = DateTime(selectedDate!.year, selectedDate!.month, 1);
    final end = DateTime(selectedDate!.year, selectedDate!.month + 1, 0);

    try {
      // Using public method to fetch entries in date range
      final data = await imageService.getAttendancePhotosForMonth(
        start: start,
        end: end,
      );
      setState(() => attendancePhotoDocs = data);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Failed to fetch attendance photos: $e")));
    }

    setState(() => isLoading = false);
  }

  // -----------------------------
  // Delete past data including attendance photos
  // -----------------------------
  Future<void> _deletePastData() async {
    if (attendances.isEmpty && notifications.isEmpty && attendancePhotoDocs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("No data to delete")));
      return;
    }

    setState(() => isLoading = true);

    try {
      for (var att in attendances) {
        await attendanceService.deleteAttendanceForAttendanceID(att.id);
      }

      for (var notif in notifications) {
        await notificationService.deleteNotificationById(notif.id);
      }

      // Delete attendance photos
      for (var uuid in attendancePhotoDocs) {
        await imageService.deleteAttendancePhoto(uuid);
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Past data deleted successfully")),
      );

      setState(() {
        attendances = [];
        notifications = [];
        attendancePhotoDocs = [];
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error deleting data: $e")));
    }

    setState(() => isLoading = false);
  }

  // -----------------------------
  // Attendance list widget
  // -----------------------------
  Widget _buildAttendanceList() {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Center(child: Text("Attendance", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold))),
          const SizedBox(height: 10),
          Expanded(
            child: attendances.isEmpty
                ? const Center(child: Text("No attendance found"))
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
                      att.scanIns.map((s) => DateService.toDisplayTime(s.time)).join(" | ") +
                          " | " +
                          att.scanOuts.map((s) => DateService.toDisplayTime(s.time)).join(" | "),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // -----------------------------
  // Notification list widget
  // -----------------------------
  Widget _buildNotificationList() {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Center(child: Text("Notifications", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold))),
          const SizedBox(height: 10),
          Expanded(
            child: notifications.isEmpty
                ? const Center(child: Text("No notifications found"))
                : ListView.builder(
              itemCount: notifications.length,
              itemBuilder: (context, index) {
                final notif = notifications[index];
                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  child: ListTile(
                    title: Text(notif.user.id),
                    subtitle: Text("Created: ${notif.createdAt.toLocal().toString().split(' ')[0]}"),
                    trailing: Text(notif.remark ?? "No remark"),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
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
                  child: Column(
                    children: [
                      _buildAttendanceList(),
                      const SizedBox(height: 20),
                      _buildNotificationList(),
                    ],
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