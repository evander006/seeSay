import 'dart:convert';

import 'package:flutter/foundation.dart';

class AppLogger {
  AppLogger({this.sink});

  /// Also writes each line to the app's diagnostic log file (see GlassesChannel.diagLog).
  final void Function(String level, String line)? sink;

  void info(String message, {String? screen, String? action}) {
    _write('info', message, screen: screen, action: action);
  }

  void warning(String message, {String? screen, String? action}) {
    _write('warning', message, screen: screen, action: action);
  }

  void error(String message, {String? screen, String? action, Object? error}) {
    _write('error', message, screen: screen, action: action, error: error);
  }

  void _write(
    String level,
    String message, {
    String? screen,
    String? action,
    Object? error,
  }) {
    final entry = <String, Object?>{
      'timestamp': DateTime.now().toIso8601String(),
      'level': level,
      'message': message,
      'screen': screen,
      'action': action,
      'error': _safe(error),
    };
    debugPrint(jsonEncode(entry));
    final where = [screen, action].whereType<String>().join(' ');
    final safe = _safe(error);
    sink?.call(
      level == 'error' ? 'E' : (level == 'warning' ? 'W' : 'I'),
      '$message${where.isEmpty ? '' : ' [$where]'}${safe == null ? '' : ' error=$safe'}',
    );
  }

  String? _safe(Object? error) {
    if (error == null) return null;
    final text = error.toString();
    if (text.length <= 240) return text;
    return '${text.substring(0, 240)}…';
  }
}
