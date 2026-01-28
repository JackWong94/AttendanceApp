import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart'; // for compute

class PasswordHasher {
  static const int _iterations = 5000;
  static const int _saltLength = 16;
  static const int _keyLength = 32;

  /// 🔹 Async hash that runs PBKDF2 off the main thread
  static Future<String> hashAsync(String password) async {
    return await compute(_hashTopLevel, password);
  }

  /// Returns: salt:hash (base64)
  static String hash(String password) {
    final salt = _generateSalt();
    final hash = _pbkdf2(password, salt);
    return '${base64Encode(salt)}:${base64Encode(hash)}';
  }

  static bool verify(String password, String stored) {
    final parts = stored.split(':');
    if (parts.length != 2) return false;

    final salt = base64Decode(parts[0]);
    final expectedHash = parts[1];

    final hash = base64Encode(_pbkdf2(password, salt));
    return _constantTimeEquals(hash, expectedHash);
  }

  static List<int> _generateSalt() {
    final rand = Random.secure();
    return List<int>.generate(_saltLength, (_) => rand.nextInt(256));
  }

  static List<int> _pbkdf2(String password, List<int> salt) {
    final hmac = Hmac(sha256, utf8.encode(password));
    var block = <int>[];

    var u = hmac.convert([...salt, 0, 0, 0, 1]).bytes;
    block = List<int>.from(u);

    for (var i = 1; i < _iterations; i++) {
      u = hmac.convert(u).bytes;
      for (var j = 0; j < block.length; j++) {
        block[j] ^= u[j];
      }
    }

    return block.sublist(0, _keyLength);
  }

  static bool _constantTimeEquals(String a, String b) {
    if (a.length != b.length) return false;
    var result = 0;
    for (var i = 0; i < a.length; i++) {
      result |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
    }
    return result == 0;
  }
}

/// 🔹 Top-level function for compute
String _hashTopLevel(String password) {
  return PasswordHasher.hash(password);
}
