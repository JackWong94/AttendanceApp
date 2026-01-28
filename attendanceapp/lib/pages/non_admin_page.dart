import 'package:flutter/material.dart';
import 'package:attendanceapp/services/tenant_model_service.dart';
import 'package:attendanceapp/services/user_model_service.dart';
import 'package:attendanceapp/services/navigation_service.dart';
import 'package:attendanceapp/models/user_model.dart';
import 'package:collection/collection.dart'; // for firstWhereOrNull
import '../main.dart'; // routeObserver
import 'package:attendanceapp/pages/non_admin_page_apply_leave.dart';
import 'package:attendanceapp/pages/non_admin_page_check_holiday_application_status.dart';
import 'package:attendanceapp/pages/non_admin_page_change_password.dart';

class NonAdminPage extends StatefulWidget {
  const NonAdminPage({super.key});

  @override
  State<NonAdminPage> createState() => _NonAdminPageState();
}

class _NonAdminPageState extends State<NonAdminPage> with RouteAware {
  final TextEditingController _passwordController = TextEditingController();
  final UserModelService _userService = UserModelService.instance;

  List<UserModel> _users = [];
  String? _selectedUserId; // store selected user ID
  bool _isLoading = true;

  UserModel? _loggedInUser; // logged-in user

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    final users = await _userService.getAllUsers();
    if (!mounted) return;

    setState(() {
      _users = users;

      // reset selection if current selected user no longer exists
      if (_selectedUserId != null &&
          !_users.any((u) => u.id == _selectedUserId)) {
        _selectedUserId = null;
      }

      _isLoading = false;
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    routeObserver.subscribe(this, ModalRoute.of(context)!);
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    _passwordController.dispose();
    super.dispose();
  }

  @override
  void didPopNext() {
    _loadUsers();
  }

  UserModel? get _selectedUser =>
      _users.firstWhereOrNull((u) => u.id == _selectedUserId);

  bool get _canLogin =>
      _selectedUserId != null && _passwordController.text.isNotEmpty;

  Future<void> _login() async {
    final user = _selectedUser;
    if (user == null) return;

    final password = _passwordController.text.trim();

    // Show loader
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final verified = await _userService.verifyUserPassword(
        userId: user.id,
        plainPassword: password,
      );

      if (verified) {
        setState(() {
          _loggedInUser = user;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("✅ Logged in as ${user.name}")),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("❌ Invalid password")),
        );
      }
    } finally {
      // Hide loader
      Navigator.of(context, rootNavigator: true).pop();
    }
  }

  void _logout() {
    setState(() {
      _loggedInUser = null;
      _passwordController.clear();
      _selectedUserId = null;
    });
  }

  void _showNotReady(String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("$feature is not implemented yet")),
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = TenantModelService.instance.currentTenantName;

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  "Self Service Portal",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),

                // Welcome message
                if (_loggedInUser != null)
                  Text(
                    "Welcome, ${_loggedInUser!.name}!",
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                      color: Colors.green,
                    ),
                  ),

                const SizedBox(height: 30),

                // Login form
                if (_loggedInUser == null) ...[
                  DropdownButtonFormField<String>(
                    value: _selectedUserId,
                    decoration: const InputDecoration(
                      labelText: "Select User",
                      border: OutlineInputBorder(),
                    ),
                    items: _users
                        .map(
                          (user) => DropdownMenuItem<String>(
                        value: user.id,
                        child: Text(user.name),
                      ),
                    )
                        .toList(),
                    onChanged: (userId) {
                      setState(() => _selectedUserId = userId);
                    },
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: _passwordController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: "Password",
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 30),
                  ElevatedButton(
                    onPressed: _canLogin ? _login : null,
                    child: const Text("Login"),
                  ),
                  const SizedBox(height: 30),
                  ElevatedButton(
                    onPressed: () => NavigationService.logOut(context),
                    child: const Text("Exit Self Service Portal"),
                  ),
                ],

                // Logged-in features
                if (_loggedInUser != null) ...[
                  ElevatedButton(
                    onPressed: () {
                      if (_loggedInUser != null) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => NonAdminPageApplyLeave(user: _loggedInUser!),
                          ),
                        );
                      }
                    },
                    child: const Text("Apply Holiday"),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: () {
                      if (_loggedInUser != null) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => NonAdminPageCheckHolidayApplicationStatus(user: _loggedInUser!),
                          ),
                        );
                      }
                    },
                    child: const Text("Check Holiday Status"),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: () {
                      if (_loggedInUser != null) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => NonAdminPageChangePassword(user: _loggedInUser!),
                          ),
                        );
                      }
                    },
                    child: const Text("Change Password"),
                  ),
                  const SizedBox(height: 30),
                  ElevatedButton(
                    onPressed: _logout,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                    ),
                    child: const Text("Logout"),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
