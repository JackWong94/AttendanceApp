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

              final notifications = snapshot.data!.docs
                  .map((doc) => LeaveNotification.fromDoc(doc))
                  .toList();

              final newNotifications = notifications
                  .where((n) => n.notificationStatus == NotificationStatus.pending)
                  .toList();

              final historyNotifications = notifications
                  .where((n) => n.notificationStatus != NotificationStatus.pending)
                  .toList();

              return TabBarView(
                controller: _tabController,
                children: [
                  _buildNotificationList(
                    newNotifications,
                    allowAction: true,
                    allowDelete: false,
                  ),
                  _buildNotificationList(
                    historyNotifications,
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
      List<LeaveNotification> notifications, {
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

              return ListTile(
                leading: Icon(
                  notif.notificationStatus == NotificationStatus.pending
                      ? Icons.pending
                      : notif.notificationStatus == NotificationStatus.approved
                      ? Icons.check_circle
                      : Icons.cancel,
                ),
                title: Text("User: $userName"),
                subtitle: Text(
                    "Attendance: ${notif.attendanceId}\nLeave: ${notif.leaveStatus.name}\nRemark: ${notif.remark}\nStatus: ${notif.notificationStatus.name}"),
                trailing: allowAction
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
