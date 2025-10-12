import 'dart:html' as html;
import 'package:flutter/material.dart';

/// Intercepts browser exit, back navigation, or tab close.
/// Works in Chrome, Edge, Safari, and PWAs.
class ExitInterceptor extends StatefulWidget {
  final Widget child;

  const ExitInterceptor({super.key, required this.child});

  @override
  State<ExitInterceptor> createState() => _ExitInterceptorState();
}

class _ExitInterceptorState extends State<ExitInterceptor> {
  @override
  void initState() {
    super.initState();

    // ✅ Prevent browser/tab close unless confirmed
    html.window.onBeforeUnload.listen((html.Event e) {
      final event = e as html.BeforeUnloadEvent;
      event.preventDefault();
      event.returnValue = ''; // Show default browser confirmation
    });
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        // ✅ Intercept Flutter back button (Android/iOS/PWA)
        final shouldExit = await _showExitConfirmation(context);
        return shouldExit; // true = exit, false = stay
      },
      child: widget.child,
    );
  }

  Future<bool> _showExitConfirmation(BuildContext context) async {
    bool? result = await showDialog<bool>(
      context: context,
      barrierDismissible: true, // ✅ allow clicking outside
      builder: (context) {
        return AlertDialog(
          title: const Text("Exit App?"),
          content: const Text("Are you sure you want to exit?"),
          actions: [
            TextButton(
              onPressed: () {
                // ✅ User cancels -> just close dialog
                Navigator.of(context).pop(false);
              },
              child: const Text("No"),
            ),
            TextButton(
              onPressed: () {
                // ✅ User confirms exit
                Navigator.of(context).pop(true);
              },
              child: const Text("Yes"),
            ),
          ],
        );
      },
    );

    // ✅ If user clicks outside or presses back while dialog open → treat as "No"
    return result ?? false;
  }
}
