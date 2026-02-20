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
              // Month Dropdown
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

              // Year Dropdown
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
              },
              child: const Text("Confirm"),
            ),
          ],
        );
      },
    );
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
              onPressed: _pickMonth,
              child: const Text("Select Month"),
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