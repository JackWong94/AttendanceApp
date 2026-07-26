import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/attendance_model.dart';
import 'user_model_service.dart';
import 'image_model_service.dart';
import 'date_service.dart';
import 'package:attendanceapp/configs_and_tools/debug.dart';
import 'package:attendanceapp/mappers/attendance_mapper.dart';

Debug debug = Debug(module: "attendance_model_service", enable: true);
class AttendanceModelService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String tenantId;

  /// Private reference to the tenant's attendance collection
  CollectionReference<Map<String, dynamic>> get _attendanceRef =>
      _firestore.collection('${tenantId}_Attendance');

  /// Expose attendance collection publicly (read-only)
  CollectionReference<Map<String, dynamic>> get attendanceRef => _attendanceRef;

  AttendanceModelService._internal(this.tenantId);

  static AttendanceModelService? _instance;

  /// Singleton instance
  static AttendanceModelService get instance {
    _instance ??= AttendanceModelService._internal(
      UserModelService.instance.tenantId,
    );
    return _instance!;
  }

  static void init({required String tenantId}) {
    _instance = AttendanceModelService._internal(tenantId);
  }

  /// Set attendance (create or update deterministically)
  Future<void> setAttendance(Attendance attendance) async {
    if (attendance.id.isEmpty) {
      throw Exception("Attendance must have a valid ID before saving.");
    }
    await _attendanceRef.doc(attendance.id).set(
        AttendanceMapper.toFirestore(attendance),
        SetOptions(merge: true), // update if exists, create if not
    );
  }

  /// Fetch attendance for a user on a specific date
  Future<Attendance?> fetchAttendanceForDate({
    required String userId,
    required String date,
  }) async {
    final docId = "${date}_$userId";
    final snapshot = await _attendanceRef.doc(docId).get();

    if (!snapshot.exists) return null;
    return AttendanceMapper.fromFirestore(snapshot);
  }

  /// Fetch all attendance for a user for a given month
  Future<List<Attendance>> fetchMonthlyAttendance({
    required String userId,
    required DateTime month,
  }) async {
    final startOfMonth = DateTime(month.year, month.month, 1);
    final endOfMonth = DateTime(month.year, month.month + 1, 0);

    final snapshots = await _attendanceRef
        .where(
      'user',
      isEqualTo: UserModelService.instance.getUserDocRef(userId),
    )
        .where(
      'date',
      isGreaterThanOrEqualTo: DateService.toStorageDate(startOfMonth),
    )
        .where(
      'date',
      isLessThanOrEqualTo: DateService.toStorageDate(endOfMonth),
    )
        .orderBy('date')
        .get();

    return snapshots.docs.map((doc) => AttendanceMapper.fromFirestore(doc)).toList();
  }

  /// Fetch attendance for a user between startDate and endDate
  Future<List<Attendance>> fetchStartToEndDateAttendanceForUser({
    required DocumentReference userRef,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final snapshots = await _attendanceRef
        .where('user', isEqualTo: userRef)
        .where(
      'date',
      isGreaterThanOrEqualTo: DateService.toStorageDate(startDate),
    )
        .where(
      'date',
      isLessThanOrEqualTo: DateService.toStorageDate(endDate),
    )
        .orderBy('date')
        .get();

    return snapshots.docs.map((doc) => AttendanceMapper.fromFirestore(doc)).toList();
  }

  /// Fetch attendance for all users between startDate and endDate
  Future<List<Attendance>> fetchAttendanceForMonthAllUsers({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final snapshots = await _attendanceRef
        .where(
      'date',
      isGreaterThanOrEqualTo: DateService.toStorageDate(startDate),
    )
        .where(
      'date',
      isLessThanOrEqualTo: DateService.toStorageDate(endDate),
    )
        .orderBy('date')
        .get();

    return snapshots.docs.map((doc) => AttendanceMapper.fromFirestore(doc)).toList();
  }
  /// Fetch all attendance for a specific user
  Future<List<Attendance>> fetchAttendanceForUser(String userId) async {
    final userRef = UserModelService.instance.getUserDocRef(userId);
    print("userRef: $userRef");
    final snapshots = await _attendanceRef
        .where('user', isEqualTo: userRef)
        .get();
    print("All documents:");
    for (var doc in snapshots.docs) {
      print(doc.id);
      print(doc.data());
    }
    return snapshots.docs.map((doc) => AttendanceMapper.fromFirestore(doc)).toList();
  }

  /// Delete a specific attendance document
  Future<void> deleteAttendance(String attendanceId) async {
    await _attendanceRef.doc(attendanceId).delete();
  }

  Future<void> deleteAllAttendanceForUser(String userId) async {
    final userRef = UserModelService.instance.getUserDocRef(userId);
    final snapshots = await _attendanceRef
        .where('user', isEqualTo: userRef)
        .get(); // no orderBy, avoids index

    final batch = _firestore.batch();

    for (var doc in snapshots.docs) {
      final data = doc.data();

      // Handle scanIns
      if (data['scanIns'] != null) {
        for (final scan in List<Map<String, dynamic>>.from(data['scanIns'])) {
          final imageUrl = scan['imageUrl'];
          if (imageUrl != null && imageUrl != 'cameraImageUrl') {
            try {
              await ImageModelService.instance.deleteAttendancePhoto(imageUrl);
              debug.log('🗑️ Deleted scanIn image: $imageUrl');
            } catch (e) {
              debug.log('⚠️ Failed to delete scanIn image: $e');
            }
          }
        }
      }

      // Handle scanOuts
      if (data['scanOuts'] != null) {
        for (final scan in List<Map<String, dynamic>>.from(data['scanOuts'])) {
          final imageUrl = scan['imageUrl'];
          if (imageUrl != null && imageUrl != 'cameraImageUrl') {
            try {
              await ImageModelService.instance.deleteAttendancePhoto(imageUrl);
              debug.log('🗑️ Deleted scanOut image: $imageUrl');
            } catch (e) {
              debug.log('⚠️ Failed to delete scanOut image: $e');
            }
          }
        }
      }

      // Queue Firestore doc for deletion
      batch.delete(doc.reference);
    }

    await batch.commit();
    debug.log('✅ Deleted all attendance documents and images for user $userId');
  }

  /// 🔄 Create or update attendance status for a user on a specific date
  Future<void> setAttendanceStatus({
    required String userId,
    required String date, // yyyy-MM-dd
    required Status status,
    required ApplicationStatus applicationStatus,
  }) async {
    final userRef = UserModelService.instance.getUserDocRef(userId);
    final attendanceId = '${date}_$userId';
    final docRef = _attendanceRef.doc(attendanceId);

    final snapshot = await docRef.get();

    if (snapshot.exists) {
      // ✅ Update existing attendance status only
      await docRef.update({
        'status': status.name,
        'applicationStatus': applicationStatus.name,
      });

      debug.log(
        '✏️ Updated attendance status: $attendanceId → ${status.name}',
      );
    } else {
      // ✅ Create new attendance with empty scan records
      final attendance = Attendance(
        id: attendanceId,
        userRef: userRef,
        date: date,
        scanIns: const [],
        scanOuts: const [],
        status: status,
        applicationStatus: applicationStatus,
      );

      await docRef.set(AttendanceMapper.toFirestore(attendance));

      debug.log(
        '🆕 Created attendance with status: $attendanceId → ${status.name}',
      );
    }
  }

  /// 🔄 Create or update application status for a user on a specific date
  Future<void> setApplicationStatus({
    required String attendanceId,
    required ApplicationStatus applicationStatus,
  }) async {
    final docRef = _attendanceRef.doc(attendanceId);

    final snapshot = await docRef.get();

    if (snapshot.exists) {
      // ✅ Update existing attendance status only
      await docRef.update({
        'applicationStatus': applicationStatus.name,
      });

      debug.log(
        '✏️ Updated application status: $attendanceId → ${applicationStatus.name}',
      );
    } else {
      debug.log(
        'Attendance Information Not Found',
      );
    }
  }

  /// Clear instance (call on logout)
  static void clear() {
    _instance = null;
  }

}
