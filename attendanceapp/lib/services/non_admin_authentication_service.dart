import 'package:attendanceapp/services/user_model_service.dart';

class NonAdminAuthenticationService {
  NonAdminAuthenticationService._();
  static final instance = NonAdminAuthenticationService._();

  /// Minimum password length rule
  static const int minPasswordLength = 6;

  /// Validate password and return error string if invalid, else null
  String? validatePassword(String password) {
    if (password.trim().isEmpty) {
      return "Password cannot be empty";
    }
    if (password.length < minPasswordLength) {
      return "Password must be at least $minPasswordLength characters";
    }
    return null;
  }

  /// Change / create password
  Future<void> changePassword({
    required String userId,
    required String plainPassword,
  }) async {
    final error = validatePassword(plainPassword);
    if (error != null) {
      throw Exception(error);
    }

    await UserModelService.instance.setUserPassword(
      userId: userId,
      plainPassword: plainPassword,
    );
  }
}
