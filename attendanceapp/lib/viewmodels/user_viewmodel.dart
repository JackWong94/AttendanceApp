import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../repositories/user_repository.dart';
import 'package:attendanceapp/configs_and_tools/debug.dart';
import 'package:attendanceapp/usecases/user/get_all_users_usecase.dart';
import 'package:attendanceapp/services/face_model_service.dart';

Debug debug = Debug(module: "user_viewmodel", enable: true);

class UserViewModel extends ChangeNotifier {
  final GetAllUsersUseCase getAllUsers;
  String _tenantId = "";
  UserViewModel(this.getAllUsers);

  List<UserModel> _users = [];
  bool _isLoading = false;
  String? _error;

  List<UserModel> get users => List.unmodifiable(_users);
  bool get isLoading => _isLoading;
  String? get error => _error;

  void setTenantId(String id) {
    _tenantId = id;
  }

  Future<void> fetchUsers() async {
    if (_isLoading) return;

    debug.log("Fetching users");

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _users = await getAllUsers(_tenantId); // ✅ FIX HERE
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();

      debug.log("Done fetching users");
      print("🔥 VM USERS UPDATED: ${users.length}");
      // 🔥 sync FaceModelService automatically
      await FaceModelService.loadEmbeddingsFromUsers(users);
      for (var user in _users) {
        debug.log("User: ${user.name}");
      }
    }

  }
  UserModel? getUserById(String id) {
    try {
      return _users.firstWhere((u) => u.id == id);
    } catch (_) {
      return null;
    }
  }

  void clear() {
    debug.log("Clearing users");
    _users = [];
    _error = null;
    notifyListeners();
  }
}