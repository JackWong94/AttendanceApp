import 'package:cloud_firestore/cloud_firestore.dart';
import 'attendance_model.dart';

enum NotificationStatus { pending, approved, rejected }

class NotificationModel {
  final String id;
  final DocumentReference user;
  final DateTime createdAt;
  final DateTime dateSafeForDelete;
  final String? remark;

  NotificationModel({
    required this.id,
    required this.user,
    DateTime? createdAt,
    DateTime? dateSafeForDelete,
    this.remark,
  }) : createdAt = createdAt ?? DateTime.now(),
        dateSafeForDelete = dateSafeForDelete ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'user': user,
      'createdAt': Timestamp.fromDate(createdAt),
      'dateSafeForDelete': Timestamp.fromDate(dateSafeForDelete),
      'remark': remark,
    };
  }

  factory NotificationModel.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return NotificationModel(
      id: doc.id,
      user: data['user'],
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      dateSafeForDelete: (data['dateSafeForDelete'] as Timestamp).toDate(),
      remark: data['remark'],
    );
  }
}

class LeaveNotification extends NotificationModel {
  final String attendanceId;
  final Status leaveStatus;
  final ApplicationStatus applicationStatus;
  final NotificationStatus notificationStatus;

  LeaveNotification({
    required String id,
    required DocumentReference user,
    required this.attendanceId,
    this.leaveStatus = Status.AL_FullDay,
    this.applicationStatus = ApplicationStatus.pending,
    this.notificationStatus = NotificationStatus.pending,
    DateTime? createdAt,
    DateTime? dateSafeForDelete,
    String? remark,
  }) : super(
    id: id,
    user: user,
    createdAt: createdAt,
    dateSafeForDelete: dateSafeForDelete,
    remark: remark,
  );

  @override
  Map<String, dynamic> toMap() {
    final map = super.toMap();
    map.addAll({
      'attendanceId': attendanceId,
      'leaveStatus': leaveStatus.name,
      'applicationStatus': applicationStatus.name,
      'notificationStatus': notificationStatus.name,
    });
    return map;
  }

  factory LeaveNotification.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return LeaveNotification(
      id: doc.id,
      user: data['user'],
      attendanceId: data['attendanceId'],
      leaveStatus: Status.values.firstWhere(
              (e) => e.name == data['leaveStatus'],
          orElse: () => Status.AL_FullDay),
      applicationStatus: ApplicationStatus.values.firstWhere(
              (e) => e.name == data['applicationStatus'],
          orElse: () => ApplicationStatus.pending),
      notificationStatus: NotificationStatus.values.firstWhere(
              (e) => e.name == data['notificationStatus'],
          orElse: () => NotificationStatus.pending),
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      remark: data['remark'],
    );
  }
}

class EmergencyAttendanceNotification extends NotificationModel {
  final String attendancePhotoDoc; // Name of the attendance photo document

  EmergencyAttendanceNotification({
    required String id,
    required DocumentReference user,
    required this.attendancePhotoDoc,
    DateTime? createdAt,
    DateTime? dateSafeForDelete,
    String? remark,
  }) : super(
    id: id,
    user: user,
    createdAt: createdAt,
    dateSafeForDelete: dateSafeForDelete,
    remark: remark,
  );

  @override
  Map<String, dynamic> toMap() {
    final map = super.toMap();
    map.addAll({
      'attendancePhotoDoc': attendancePhotoDoc,
    });
    return map;
  }

  factory EmergencyAttendanceNotification.fromDoc(
      DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return EmergencyAttendanceNotification(
      id: doc.id,
      user: data['user'],
      attendancePhotoDoc: data['attendancePhotoDoc'] ?? "",
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      dateSafeForDelete: (data['dateSafeForDelete'] as Timestamp?)?.toDate(),
      remark: data['remark'],
    );
  }
}