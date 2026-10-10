import 'package:flutter/widgets.dart';
import 'package:seesay/core/accessibility/accessibility_audio_service.dart';
import 'package:seesay/core/accessibility/haptic_service.dart';

class AppScope extends InheritedWidget {
  const AppScope({
    required this.audio,
    required this.feedback,
    required this.repeatLast,
    required super.child,
    super.key,
  });

  final AccessibilityAudioService audio;
  final SystemFeedback feedback;
  final Future<void> Function() repeatLast;

  static AppScope of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'AppScope is missing');
    return scope!;
  }

  @override
  bool updateShouldNotify(covariant AppScope oldWidget) {
    return audio != oldWidget.audio ||
        feedback != oldWidget.feedback ||
        repeatLast != oldWidget.repeatLast;
  }
}
