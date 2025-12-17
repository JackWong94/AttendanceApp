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

enum Status {
  FullDay,
  HalfDay,
  AL_FullDay,
  AL_HalfDay,
  UL_FullDay,
  UL_HalfDay,
  PH_FullDay,
  PH_HalfDay,
  MC_FullDay,
  MC_HalfDay,
}

// ✅ Correct const usage


class Attendance {
  static const defaultStatus = Status.FullDay;
  final String id; // Firestore doc ID
  final DocumentReference userRef; // Ref to user document
  final String date; // "yyyy-MM-dd"

  final List<ScanRecord> scanIns;
  final List<ScanRecord> scanOuts;
  final Status status;

  Attendance({
    required this.id,
    required this.userRef,
    required this.date,
    required this.scanIns,
    required this.scanOuts,
    this.status = defaultStatus,
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
        status: defaultStatus,
      );
    }

    Status parseStatus(String? raw) {
      if (raw == null || raw.isEmpty) return defaultStatus;
      // Convert string to enum
      return Status.values.firstWhere(
            (e) => e.name == raw,
        orElse: () => defaultStatus,
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
      status: parseStatus(data['status'] as String?),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'user': userRef,
      'date': date,
      'scanIns': scanIns.map((r) => r.toMap()).toList(),
      'scanOuts': scanOuts.map((r) => r.toMap()).toList(),
      'status': status.name, // store enum as string in Firestore
    };
  }
}
