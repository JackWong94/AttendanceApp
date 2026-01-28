import 'package:flutter/material.dart';
import 'service_portal_admin_notification_page.dart';
import 'service_portal_admin_set_public_holiday_page.dart';

class ServicePortalAdminPage extends StatefulWidget {
  const ServicePortalAdminPage({super.key});

  @override
  State<ServicePortalAdminPage> createState() => _ServicePortalAdminPageState();
}

class _ServicePortalAdminPageState extends State<ServicePortalAdminPage> {
  int _selectedIndex = 0;

  // Pages inside the main Service Portal Admin page
  final List<Widget> _pages = const [
    ServicePortalAdminNotificationPage(),
    ServicePortalAdminSetPublicHolidayPage(),
  ];

  // Titles corresponding to the drawer items
  final List<String> _pageTitles = [
    "Service Portal Admin - Notification",
    "Service Portal Admin - Set Public Holiday",
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_pageTitles[_selectedIndex]),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          Builder(
            builder: (context) => IconButton(
              icon: const Icon(Icons.menu),
              onPressed: () => Scaffold.of(context).openEndDrawer(),
            ),
          ),
        ],
      ),
      endDrawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            const DrawerHeader(
              decoration: BoxDecoration(color: Colors.blue),
              child: Text("Service Portal Admin",
                  style: TextStyle(color: Colors.white, fontSize: 24)),
            ),
            ListTile(
              leading: const Icon(Icons.notifications),
              title: const Text("Notification"),
              selected: _selectedIndex == 0,
              onTap: () {
                setState(() => _selectedIndex = 0);
                Navigator.pop(context); // close drawer
              },
            ),
            ListTile(
              leading: const Icon(Icons.event),
              title: const Text("Set Public Holiday"),
              selected: _selectedIndex == 1,
              onTap: () {
                setState(() => _selectedIndex = 1);
                Navigator.pop(context); // close drawer
              },
            ),
          ],
        ),
      ),
      body: _pages[_selectedIndex],
    );
  }
}
