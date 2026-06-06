import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../repositories/user_repository.dart';

class UserViewModel extends ChangeNotifier {
  final UserRepository _repo;

  UserViewModel(this._repo);

  List<UserModel> _users = [];
  bool _isLoading = false;
  String? _error;

  List<UserModel> get users => _users;
  bool get isLoading => _isLoading;
  String? get error => _error;

  // 🔥 Load users from repository
  Future<void> fetchUsers() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _users = await _repo.getAllUsers();
    } catch (e) {
      _error = e.toString();
    }

    _isLoading = false;
    notifyListeners();
  }

  void clear() {
    _users = [];
    _error = null;
    notifyListeners();
  }
}