import 'package:cloud_firestore/cloud_firestore.dart';

class Attendance {
  final String id; // Firestore document ID
  final DocumentReference userRef; // Firestore reference to the user
  final String userName;
  final String date; // "yyyy-MM-dd" format

  // Scan times
  DateTime? scanIn;
  DateTime? scanOut;
  DateTime? scanInLunch;
  DateTime? scanOutLunch;
  DateTime? scanInOt;
  DateTime? scanOutOt;

  Attendance({
    required this.id,
    required this.userRef,
    required this.userName,
    required this.date,
    this.scanIn,
    this.scanOut,
    this.scanInLunch,
    this.scanOutLunch,
    this.scanInOt,
    this.scanOutOt,
  });

  /// Convert Firestore document to Attendance object
  factory Attendance.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return Attendance(
      id: doc.id,
      userRef: data['user'] as DocumentReference,
      userName: data['userName'] ?? '',
      date: data['date'] ?? '',
      scanIn: data['scanIn'] != null ? (data['scanIn'] as Timestamp).toDate() : null,
      scanOut: data['scanOut'] != null ? (data['scanOut'] as Timestamp).toDate() : null,
      scanInLunch: data['scanInLunch'] != null ? (data['scanInLunch'] as Timestamp).toDate() : null,
      scanOutLunch: data['scanOutLunch'] != null ? (data['scanOutLunch'] as Timestamp).toDate() : null,
      scanInOt: data['scanInOt'] != null ? (data['scanInOt'] as Timestamp).toDate() : null,
      scanOutOt: data['scanOutOt'] != null ? (data['scanOutOt'] as Timestamp).toDate() : null,
    );
  }

  /// Convert Attendance object to Firestore map
  Map<String, dynamic> toMap() {
    return {
      'user': userRef,
      'userName': userName,
      'date': date,
      'scanIn': scanIn != null ? Timestamp.fromDate(scanIn!) : null,
      'scanOut': scanOut != null ? Timestamp.fromDate(scanOut!) : null,
      'scanInLunch': scanInLunch != null ? Timestamp.fromDate(scanInLunch!) : null,
      'scanOutLunch': scanOutLunch != null ? Timestamp.fromDate(scanOutLunch!) : null,
      'scanInOt': scanInOt != null ? Timestamp.fromDate(scanInOt!) : null,
      'scanOutOt': scanOutOt != null ? Timestamp.fromDate(scanOutOt!) : null,
    };
  }
}
