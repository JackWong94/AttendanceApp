import 'package:flutter/material.dart';

class SnackBarHelper {
  static String? _lastMessage;
  static ScaffoldFeatureController<SnackBar, SnackBarClosedReason>? _currentSnackBar;

  static void show(
      BuildContext context,
      String message, {
        Color? backgroundColor,
        int seconds = 2,
      }) {
    final messenger = ScaffoldMessenger.of(context);

    // If same message already showing, do nothing
    if (_lastMessage == message) return;

    _lastMessage = message;

    // If a different SnackBar is showing, hide it immediately
    _currentSnackBar?.close();

    _currentSnackBar = messenger.showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: backgroundColor,
        duration: Duration(seconds: seconds),
        behavior: SnackBarBehavior.floating,
      ),
    );

    // Reset last message after SnackBar ends
    _currentSnackBar!.closed.then((_) {
      _lastMessage = null;
      _currentSnackBar = null;
    });
  }
}
