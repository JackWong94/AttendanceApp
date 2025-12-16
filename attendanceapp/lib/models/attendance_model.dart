import 'package:cloud_firestore/cloud_firestore.dart';

class ScanRecord {
  final DateTime time;
  final String imageUrl; // required since stored in Storage

  ScanRecord({
    required this.time,
    required this.imageUrl,
  });

  factory ScanRecord.fromMap(Map<String, dynamic> map) {
    return ScanRecord(
      time: (map['time'] as Timestamp).toDate(),
      imageUrl: map['imageUrl'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'time': Timestamp.fromDate(time),
      'imageUrl': imageUrl,
    };
  }
}

enum LeaveType {
  annualLeave,
  unpaidLeave,
  publicHoliday,
  mc,
  na,
}

enum LeaveDay {
  fullDay,
  halfDay,
  na,
}
class Leave {
  final LeaveType type;
  final LeaveDay day;

  const Leave({
    required this.type,
    required this.day,
  });

  factory Leave.fromMap(Map<String, dynamic> map) {
    return Leave(
      type: LeaveType.values.byName(map['type'] ?? 'na'),
      day: LeaveDay.values.byName(map['day'] ?? 'fullDay'),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'type': type.name,
      'day': day.name,
    };
  }

  /// Default leave (no leave)
  static const none = Leave(
    type: LeaveType.na,
    day: LeaveDay.na,
  );
}

class Attendance {
  final String id; // Firestore doc ID
  final DocumentReference userRef; // Ref to user document
  final String date; // "yyyy-MM-dd"

  final List<ScanRecord> scanIns;
  final List<ScanRecord> scanOuts;
  final Leave leave;

  Attendance({
    required this.id,
    required this.userRef,
    required this.date,
    required this.scanIns,
    required this.scanOuts,
    this.leave = Leave.none,
  });

  factory Attendance.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    if (data == null) {
      // Defensive fallback to prevent null crash
      return Attendance(
        id: doc.id,
        userRef: FirebaseFirestore.instance.doc('users/unknown'),
        date: '',
        scanIns: [],
        scanOuts: [],
        leave: Leave.none,
      );
    }

    return Attendance(
      id: doc.id,
      userRef: data['user'] as DocumentReference? ??
          FirebaseFirestore.instance.doc('users/unknown'),
      date: data['date'] ?? '',
      scanIns: (data['scanIns'] as List? ?? [])
          .map((e) => ScanRecord.fromMap(Map<String, dynamic>.from(e)))
          .toList(),
      scanOuts: (data['scanOuts'] as List? ?? [])
          .map((e) => ScanRecord.fromMap(Map<String, dynamic>.from(e)))
          .toList(),
      leave: data['leave'] != null
          ? Leave.fromMap(Map<String, dynamic>.from(data['leave']))
          : Leave.none, // ✅ default
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'user': userRef,
      'date': date,
      'scanIns': scanIns.map((r) => r.toMap()).toList(),
      'scanOuts': scanOuts.map((r) => r.toMap()).toList(),
      'leave': leave.toMap(),
    };
  }
}
