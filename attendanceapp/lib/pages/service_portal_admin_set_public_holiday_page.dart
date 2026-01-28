import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../services/user_model_service.dart';

class ServicePortalAdminSetPublicHolidayPage extends StatefulWidget {
  const ServicePortalAdminSetPublicHolidayPage({super.key});

  @override
  State<ServicePortalAdminSetPublicHolidayPage> createState() =>
      _ServicePortalAdminSetPublicHolidayPageState();
}

class _ServicePortalAdminSetPublicHolidayPageState
    extends State<ServicePortalAdminSetPublicHolidayPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  DateTime? _selectedDate;
  String _phType = 'PH_FullDay';
  int _selectedMonth = DateTime.now().month;

  CollectionReference<Map<String, dynamic>> get _attendanceRef =>
      _firestore.collection('${UserModelService.instance.tenantId}_Attendance');

  CollectionReference<Map<String, dynamic>> get _usersRef =>
      _firestore.collection('${UserModelService.instance.tenantId}_Users');

  /// Pick holiday date
  Future<void> _pickHolidayDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(DateTime.now().year - 1),
      lastDate: DateTime(DateTime.now().year + 5),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  /// Apply PH to all members
  Future<void> _applyHolidayToAll() async {
    if (_selectedDate == null) return;

    final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate!);

    final usersSnapshot = await _usersRef.get();
    final batch = _firestore.batch();

    for (final user in usersSnapshot.docs) {
      batch.set(
        _attendanceRef.doc('${dateStr}_${user.id}'),
        {
          'userId': user.id,
          'date': dateStr,
          'status': _phType,
          'applicationStatus': 'approved',
        },
        SetOptions(merge: true),
      );
    }

    await batch.commit();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Public holiday applied to all members")),
    );

    setState(() => _selectedDate = null);
  }

  /// Remove PH by changing status back to FullDay
  Future<void> _removeHoliday(String dateStr) async {
    final snapshot = await _attendanceRef
        .where('date', isEqualTo: dateStr)
        .where('status', whereIn: ['PH_FullDay', 'PH_HalfDay'])
        .get();

    final batch = _firestore.batch();
    for (final doc in snapshot.docs) {
      batch.update(doc.reference, {'status': 'FullDay'});
    }

    await batch.commit();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Public holiday removed (status reset to FullDay)")),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        /// ACTION PANEL
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              OutlinedButton.icon(
                icon: const Icon(Icons.date_range),
                label: Text(
                  _selectedDate == null
                      ? "Select Holiday Date"
                      : "Selected: ${DateFormat('yyyy-MM-dd').format(_selectedDate!)}",
                ),
                onPressed: _pickHolidayDate,
              ),
              const SizedBox(height: 12),
              DropdownButton<String>(
                value: _phType,
                items: const [
                  DropdownMenuItem(
                    value: 'PH_FullDay',
                    child: Text('Public Holiday (Full Day)'),
                  ),
                  DropdownMenuItem(
                    value: 'PH_HalfDay',
                    child: Text('Public Holiday (Half Day)'),
                  ),
                ],
                onChanged: (v) => setState(() => _phType = v!),
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                icon: const Icon(Icons.public),
                label: const Text("Apply Public Holiday to All Members"),
                onPressed: _selectedDate == null ? null : _applyHolidayToAll,
              ),
              const SizedBox(height: 12),

              /// Month selector
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text("See Public Holiday For Month: "),
                  DropdownButton<int>(
                    value: _selectedMonth,
                    items: List.generate(12, (index) {
                      return DropdownMenuItem(
                        value: index + 1,
                        child: Text(DateFormat.MMMM()
                            .format(DateTime(0, index + 1))),
                      );
                    }),
                    onChanged: (v) {
                      if (v != null) setState(() => _selectedMonth = v);
                    },
                  ),
                ],
              ),
            ],
          ),
        ),

        const Divider(),

        /// HOLIDAY / ATTENDANCE LIST (unique dates only)
        Expanded(
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _attendanceRef
                .where('status', whereIn: ['PH_FullDay', 'PH_HalfDay'])
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const Center(child: Text("No public holidays found"));
              }

              // Aggregate unique dates
              final dateMap = <String, String>{}; // dateStr -> type
              for (final doc in snapshot.data!.docs) {
                final data = doc.data();
                final dateStr =
                    data['date'] as String? ?? doc.id.split('_').first;
                final dt = DateTime.tryParse(dateStr);
                if (dt != null && dt.month == _selectedMonth) {
                  // keep only first occurrence for the date
                  dateMap.putIfAbsent(dateStr, () => data['status'] ?? 'PH_FullDay');
                }
              }

              if (dateMap.isEmpty) {
                return const Center(child: Text("No holidays in this month"));
              }

              final dates = dateMap.keys.toList()..sort();

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: dates.length,
                itemBuilder: (context, index) {
                  final dateStr = dates[index];
                  final type = dateMap[dateStr]!;

                  return Card(
                    child: ListTile(
                      title: Text("$dateStr • $type"),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () => _removeHoliday(dateStr),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
