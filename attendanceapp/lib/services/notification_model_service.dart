import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/notification_model.dart';
import 'user_model_service.dart';

class NotificationModelService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String tenantId;

  CollectionReference<Map<String, dynamic>> get _notificationRef =>
      _firestore.collection('${tenantId}_Notifications');

  NotificationModelService._internal(this.tenantId);

  static NotificationModelService? _instance;

  static NotificationModelService get instance {
    _instance ??= NotificationModelService._internal(
      UserModelService.instance.tenantId,
    );
    return _instance!;
  }

  static void init({required String tenantId}) {
    _instance = NotificationModelService._internal(tenantId);
  }

  static void clear() {
    _instance = null;
  }

  /// 🔔 Create notification when leave is applied
  Future<void> createForLeaveApplication({
    required String attendanceId,      // e.g., "2025-10-25_EMP0001"
    required String status,           // e.g., "AL_FullDay"
    required DocumentReference userRef,
    required DateTime? leaveDate,
    String? remark,
  }) async {
    // Extract date part from attendanceId (assuming attendanceId = "yyyy-MM-dd_USERID")
    final datePart = attendanceId.split('_').first;

    // Use user ID from DocumentReference
    final userId = userRef.id;

    // Construct custom doc ID: "2025-10-25_EMP0001"
    final docId = '${datePart}_$userId';

    final doc = _notificationRef.doc(docId);
    final dateSafeForDelete = leaveDate;
    final notification = LeaveNotification(
      id: doc.id,
      user: userRef,
      attendanceId: attendanceId,
      dateSafeForDelete: dateSafeForDelete,
      remark: remark,
    );

    await doc.set(notification.toMap());
  }


  /// ✅ Approve notification
  Future<void> approve(NotificationModel notification) async {
    await _notificationRef.doc(notification.id).update({
      'notificationStatus': NotificationStatus.approved.name,
    });
  }

  /// ❌ Reject notification
  Future<void> reject(NotificationModel notification, String remark) async {
    await _notificationRef.doc(notification.id).update({
      'notificationStatus': NotificationStatus.rejected.name,
    });
  }

  /// Fetch pending notifications
  Future<List<NotificationModel>> fetchPending() async {
    final snapshot = await _notificationRef
        .where('status', isEqualTo: NotificationStatus.pending.name)
        .orderBy('createdAt')
        .get();

    return snapshot.docs
        .map((doc) => NotificationModel.fromDoc(doc))
        .toList();
  }

  /// Stream all notifications (real-time updates)
  Stream<QuerySnapshot<Map<String, dynamic>>> notificationsStream() {
    return _notificationRef.orderBy('createdAt', descending: true).snapshots();
  }

  /// Fetch notifications whose dateSafeForDelete is between start and end
  Future<List<NotificationModel>> fetchBySafeDeleteDate({
    required DateTime start,
    required DateTime end,
  }) async {
    final snapshot = await _notificationRef
        .where('dateSafeForDelete', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('dateSafeForDelete', isLessThanOrEqualTo: Timestamp.fromDate(end))
        .orderBy('dateSafeForDelete')
        .get();

    return snapshot.docs
        .map((doc) => NotificationModel.fromDoc(doc))
        .toList();
  }
  /// Delete a notification by ID
  Future<void> deleteNotificationById(String notificationId) async {
    try {
      await _notificationRef.doc(notificationId).delete();
      print("Notification $notificationId deleted successfully");
    } catch (e) {
      print("Error deleting notification $notificationId: $e");
      rethrow;
    }
  }
}
