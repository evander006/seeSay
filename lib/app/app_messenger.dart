import 'package:flutter/material.dart';

final appMessengerKey = GlobalKey<ScaffoldMessengerState>();

void showAppMessage(String message) {
  final trimmed = message.trim();
  if (trimmed.isEmpty) return;
  final messenger = appMessengerKey.currentState;
  if (messenger == null) return;
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(trimmed),
        behavior: SnackBarBehavior.floating,
      ),
    );
}
