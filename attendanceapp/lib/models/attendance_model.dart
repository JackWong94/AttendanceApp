import 'package:cloud_firestore/cloud_firestore.dart';

class ScanRecord {
  final DateTime time;
  final String imageUrl;

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
  FullDay('1'),
  HalfDay('0.5'),
  AL_FullDay('AL'),
  AL_HalfDay('AL_H'),
  UL_FullDay('UL'),
  UL_HalfDay('UL_H'),
  PH_FullDay('PH'),
  PH_HalfDay('PH_H'),
  MC_FullDay('MC'),
  MC_HalfDay('MC_H'),
  Absent('0'),
  SUN('SUN');

  final String code;
  const Status(this.code);
}

/// New enum for leave application status
enum ApplicationStatus { pending, approved , declined , none}

class Attendance {
  static const defaultStatus = Status.FullDay;
  static const defaultApplicationStatus = ApplicationStatus.none;

  final String id; // Firestore doc ID
  final DocumentReference userRef;
  final String date; // "yyyy-MM-dd"

  final List<ScanRecord> scanIns;
  final List<ScanRecord> scanOuts;
  final Status status;
  final ApplicationStatus applicationStatus; // ✅ new field

  Attendance({
    required this.id,
    required this.userRef,
    required this.date,
    required this.scanIns,
    required this.scanOuts,
    this.status = defaultStatus,
    this.applicationStatus = defaultApplicationStatus, // default
  });

  factory Attendance.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    if (data == null) {
      return Attendance(
        id: doc.id,
        userRef: FirebaseFirestore.instance.doc('users/unknown'),
        date: '',
        scanIns: [],
        scanOuts: [],
        status: defaultStatus,
        applicationStatus: defaultApplicationStatus,
      );
    }

    Status parseStatus(String? raw) {
      if (raw == null || raw.isEmpty) return defaultStatus;
      return Status.values.firstWhere(
            (e) => e.name == raw,
        orElse: () => defaultStatus,
      );
    }

    ApplicationStatus parseApplicationStatus(String? raw) {
      if (raw == null || raw.isEmpty) return defaultApplicationStatus;
      return ApplicationStatus.values.firstWhere(
            (e) => e.name == raw,
        orElse: () => defaultApplicationStatus,
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
      applicationStatus: parseApplicationStatus(data['applicationStatus'] as String?),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'user': userRef,
      'date': date,
      'scanIns': scanIns.map((r) => r.toMap()).toList(),
      'scanOuts': scanOuts.map((r) => r.toMap()).toList(),
      'status': status.name,
      'applicationStatus': applicationStatus.name, // ✅ store enum as string
    };
  }
}
