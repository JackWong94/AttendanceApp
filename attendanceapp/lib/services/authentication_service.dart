import 'package:firebase_auth/firebase_auth.dart';

class AuthenticationService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  AuthenticationService() {
    // Ensure web login persistence
    _auth.setPersistence(Persistence.LOCAL);
  }

  /// Get currently logged-in user
  User? get currentUser => _auth.currentUser;

  /// Stream to listen to authentication changes
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// Sign in with email & password
  Future<void> signIn({required String email, required String password}) async {
    try {
      await _auth.signInWithEmailAndPassword(email: email, password: password);
    } on FirebaseAuthException catch (e) {
      // Rethrow so UI can handle
      throw FirebaseAuthException(code: e.code, message: e.message);
    }
  }

  /// Sign out user
  Future<void> signOut() async {
    await _auth.signOut();
  }
}
