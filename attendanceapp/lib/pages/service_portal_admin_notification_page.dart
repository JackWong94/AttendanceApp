import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:attendanceapp/models/notification_model.dart';
import 'package:attendanceapp/services/notification_model_service.dart';
import 'package:attendanceapp/services/user_model_service.dart';
import 'package:attendanceapp/services/attendance_model_service.dart';
import 'package:attendanceapp/models/user_model.dart';
import 'package:attendanceapp/models/attendance_model.dart';

class ServicePortalAdminNotificationPage extends StatefulWidget {
  const ServicePortalAdminNotificationPage({super.key});

  @override
  State<ServicePortalAdminNotificationPage> createState() =>
      _ServicePortalAdminNotificationPageState();
}

class _ServicePortalAdminNotificationPageState
    extends State<ServicePortalAdminNotificationPage>
    with SingleTickerProviderStateMixin {
  final NotificationModelService _notifService =
      NotificationModelService.instance;

  final Map<String, String> _userNameCache = {};
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  Future<String> _getUserName(DocumentReference userRef) async {
    final userId = userRef.id;
    if (_userNameCache.containsKey(userId)) return _userNameCache[userId]!;

    final user = await UserModelService.instance.getUserById(userId);
    final name = user?.name ?? "Unknown";
    _userNameCache[userId] = name;
    return name;
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _notificationsStream() {
    return FirebaseFirestore.instance
        .collection('${UserModelService.instance.tenantId}_Notifications')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  NotificationModel _parseNotification(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    // Check if the doc has the emergency photo field
    if (data.containsKey('attendancePhotoDoc')) {
      return EmergencyAttendanceNotification.fromDoc(doc);
    }
    return LeaveNotification.fromDoc(doc);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TabBar(
          controller: _tabController,
          labelColor: Theme.of(context).colorScheme.primary,
          tabs: const [
            Tab(text: "New Notifications"),
            Tab(text: "History"),
          ],
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _notificationsStream(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(child: Text("Error: ${snapshot.error}"));
              }
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const Center(child: Text("No notifications"));
              }

              // Map docs to correct notification type
              final notifications = snapshot.data!.docs
                  .map((doc) => _parseNotification(doc))
                  .toList();

              // Separate new and history
              final newNotifications = notifications
                  .where((n) =>
                  n.notificationStatus == NotificationStatus.pending)
                  .toList();

              final historyNotifications = notifications
                  .where((n) =>
              !(
                  n.notificationStatus == NotificationStatus.pending))
                  .toList();

              return TabBarView(
                controller: _tabController,
                children: [
                  _buildNotificationList(
                    newNotifications.cast<NotificationModel>(),
                    allowAction: true,
                    allowDelete: false,
                  ),
                  _buildNotificationList(
                    historyNotifications.cast<NotificationModel>(),
                    allowAction: false,
                    allowDelete: true,
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildNotificationList(
      List<NotificationModel> notifications, {
        required bool allowAction,
        required bool allowDelete,
      }) {
    if (notifications.isEmpty) return const Center(child: Text("No notifications"));

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: notifications.length,
      itemBuilder: (context, index) {
        final notif = notifications[index];

        return Card(
          margin: const EdgeInsets.symmetric(vertical: 8),
          child: FutureBuilder<String>(
            future: _getUserName(notif.user),
            builder: (context, userSnapshot) {
              final userName =
                  userSnapshot.data ?? notif.user.id.split('/').last;

              String subtitleText = "";
              Icon leadingIcon = const Icon(Icons.notifications);

              if (notif is LeaveNotification) {
                subtitleText =
                "Attendance: ${notif.attendanceId}\nLeave: ${notif.leaveStatus.name}\nRemark: ${notif.remark ?? ""}\nStatus: ${notif.notificationStatus.name}";
                leadingIcon = Icon(
                  notif.notificationStatus == NotificationStatus.pending
                      ? Icons.pending
                      : notif.notificationStatus == NotificationStatus.approved
                      ? Icons.check_circle
                      : Icons.cancel,
                  color: notif.notificationStatus == NotificationStatus.pending
                      ? Colors.orange
                      : notif.notificationStatus == NotificationStatus.approved
                      ? Colors.green
                      : Colors.red,
                );
              } else if (notif is EmergencyAttendanceNotification) {
                subtitleText =
                "Emergency Photo Doc: ${notif.attendancePhotoDoc}\nRemark: ${notif.remark ?? ""}";
                leadingIcon = const Icon(Icons.photo_camera, color: Colors.blue);
              } else {
                subtitleText = "Remark: ${notif.remark ?? ""}";
              }

              return ListTile(
                leading: leadingIcon,
                title: Text("User: $userName"),
                subtitle: Text(subtitleText),
                trailing: notif is LeaveNotification && allowAction
                    ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.check, color: Colors.green),
                      onPressed: () async {
                        await _notifService.approve(notif);
                        await AttendanceModelService.instance
                            .setApplicationStatus(
                          attendanceId: notif.attendanceId,
                          applicationStatus: ApplicationStatus.approved,
                        );
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.red),
                      onPressed: () async {
                        await _notifService.reject(notif, "Rejected by admin");
                        await AttendanceModelService.instance
                            .setApplicationStatus(
                          attendanceId: notif.attendanceId,
                          applicationStatus: ApplicationStatus.declined,
                        );
                      },
                    ),
                  ],
                )
                    : allowDelete
                    ? IconButton(
                  icon: const Icon(Icons.delete, color: Colors.grey),
                  onPressed: () async {
                    await FirebaseFirestore.instance
                        .collection(
                        '${UserModelService.instance.tenantId}_Notifications')
                        .doc(notif.id)
                        .delete();
                  },
                )
                    : null,
              );
            },
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
}