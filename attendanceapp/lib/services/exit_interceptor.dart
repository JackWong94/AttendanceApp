// lib/services/exit_interceptor.dart
import 'dart:html' as html;

/// ExitInterceptor: prevents the user from accidentally leaving the web app.
///
/// Only triggers when the browser tab is being closed or refreshed.
/// Does NOT block in-app navigation.
class ExitInterceptor {
  static bool _enabled = false;
  static html.EventListener? _handler;

  static void enable() {
    if (_enabled) return;
    _enabled = true;

    _handler = (event) {
      event.preventDefault();
      (event as dynamic).returnValue = ''; // required to trigger the browser dialog
    };

    html.window.addEventListener('beforeunload', _handler!);
  }

  static void disable() {
    if (!_enabled) return;
    _enabled = false;

    if (_handler != null) {
      html.window.removeEventListener('beforeunload', _handler!);
      _handler = null;
    }
  }
}
