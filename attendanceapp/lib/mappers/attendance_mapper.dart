import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/attendance_model.dart';


class AttendanceMapper {


  static Attendance fromFirestore(
      DocumentSnapshot<Map<String, dynamic>> doc,
      ) {

    final data = doc.data();


    if (data == null) {
      throw Exception(
          "Attendance ${doc.id} has no data");
    }


    return Attendance(

      id: doc.id,


      userRef:
      data['user'] as DocumentReference? ??
          FirebaseFirestore.instance
              .doc('users/unknown'),


      date:
      data['date'] ?? '',


      scanIns:
      _parseScanRecords(data['scanIns']),


      scanOuts:
      _parseScanRecords(data['scanOuts']),


      status:
      _parseStatus(data['status']),


      applicationStatus:
      _parseApplicationStatus(
          data['applicationStatus']),
    );
  }



  static Map<String,dynamic> toFirestore(
      Attendance attendance,
      ){

    return {

      'user':
      attendance.userRef,


      'date':
      attendance.date,


      'scanIns':
      attendance.scanIns
          .map(_scanRecordToMap)
          .toList(),


      'scanOuts':
      attendance.scanOuts
          .map(_scanRecordToMap)
          .toList(),


      'status':
      attendance.status.name,


      'applicationStatus':
      attendance.applicationStatus.name,
    };
  }



  static List<ScanRecord> _parseScanRecords(
      dynamic value,
      ){

    if(value is! List){
      return [];
    }


    return value.map((e){

      final map =
      Map<String,dynamic>.from(e);


      return ScanRecord(
        time:
        (map['time'] as Timestamp)
            .toDate(),

        imageUrl:
        map['imageUrl'] ?? '',
      );

    }).toList();
  }



  static Map<String,dynamic> _scanRecordToMap(
      ScanRecord record,
      ){

    return {

      'time':
      Timestamp.fromDate(record.time),

      'imageUrl':
      record.imageUrl,
    };
  }




  static Status _parseStatus(dynamic value){

    return Status.values.firstWhere(
          (e)=> e.name == value,
      orElse: ()=> Attendance.defaultStatus,
    );

  }



  static ApplicationStatus
  _parseApplicationStatus(dynamic value){

    return ApplicationStatus.values.firstWhere(
          (e)=> e.name == value,
      orElse: ()=>
      Attendance.defaultApplicationStatus,
    );

  }

}