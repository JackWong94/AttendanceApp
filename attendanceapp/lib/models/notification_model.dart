import 'package:cloud_firestore/cloud_firestore.dart';
import 'attendance_model.dart';

enum NotificationStatus { pending, approved, rejected }

class NotificationModel {
  final String id;
  final DocumentReference user;
  final DateTime createdAt;
  final String? remark;

  NotificationModel({
    required this.id,
    required this.user,
    DateTime? createdAt,
    this.remark,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'user': user,
      'createdAt': Timestamp.fromDate(createdAt),
      'remark': remark,
    };
  }

  factory NotificationModel.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return NotificationModel(
      id: doc.id,
      user: data['user'],
      createdAt: (data['createdAt'] as Timestamp).toDate(),
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
    String? remark,
  }) : super(
    id: id,
    user: user,
    createdAt: createdAt,
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
