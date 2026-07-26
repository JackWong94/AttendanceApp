import 'package:cloud_firestore/cloud_firestore.dart';

class ScanRecord {
  final DateTime time;
  final String imageUrl;

  ScanRecord({
    required this.time,
    required this.imageUrl,
  });
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


enum ApplicationStatus {
  pending,
  approved,
  declined,
  none
}


class Attendance {

  static const defaultStatus = Status.FullDay;
  static const defaultApplicationStatus =
      ApplicationStatus.none;


  final String id;
  final DocumentReference userRef;
  final String date;

  final List<ScanRecord> scanIns;
  final List<ScanRecord> scanOuts;

  final Status status;
  final ApplicationStatus applicationStatus;


  Attendance({
    required this.id,
    required this.userRef,
    required this.date,
    required this.scanIns,
    required this.scanOuts,
    this.status = defaultStatus,
    this.applicationStatus =
        defaultApplicationStatus,
  });
}