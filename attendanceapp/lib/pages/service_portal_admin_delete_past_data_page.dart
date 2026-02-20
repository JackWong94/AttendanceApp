import 'package:flutter/material.dart';

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

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );

    if (picked != null) {
      setState(() {
        selectedDate = picked;
      });
    }
  }

  Future<void> _deletePastData() async {
    if (selectedDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select a date first")),
      );
      return;
    }

    setState(() => isLoading = true);

    try {
      // TODO: call your delete service here
      // await AttendanceService.instance.deleteBefore(selectedDate!);

      await Future.delayed(const Duration(seconds: 2)); // simulate

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Past data deleted successfully")),
      );
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
      appBar: AppBar(
        title: const Text("Delete Past Data"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Text(
              "Select a date. All records before this date will be deleted.",
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 20),

            ElevatedButton(
              onPressed: _pickDate,
              child: const Text("Select Date"),
            ),

            const SizedBox(height: 10),

            if (selectedDate != null)
              Text(
                "Selected: ${selectedDate!.toLocal()}".split(' ')[0],
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),

            const SizedBox(height: 30),

            isLoading
                ? const CircularProgressIndicator()
                : ElevatedButton(
              onPressed: _deletePastData,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
              ),
              child: const Text("Delete Past Records"),
            ),
          ],
        ),
      ),
    );
  }
}