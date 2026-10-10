import 'package:flutter/services.dart';
import 'package:seesay/core/logging/app_logger.dart';
import 'package:seesay/core/platform/glasses_protocol.dart';

enum HapticKind { tap, success, error, connection, capture }

abstract class SystemFeedback {
  Future<void> haptic(HapticKind kind);

  Future<void> beep(HapticKind kind);
}

class ChannelSystemFeedback implements SystemFeedback {
  ChannelSystemFeedback({required this.channel, required this.logger});

  final MethodChannel channel;
  final AppLogger logger;

  @override
  Future<void> haptic(HapticKind kind) async {
    try {
      await channel.invokeMethod<void>('haptic', {'kind': kind.name});
    } on Object catch (error) {
      logger.error('haptic failed', action: kind.name, error: error);
      await FallbackSystemFeedback().haptic(kind);
    }
  }

  @override
  Future<void> beep(HapticKind kind) async {
    try {
      await channel.invokeMethod<void>('beep', {'kind': kind.name});
    } on Object catch (error) {
      logger.error('beep failed', action: kind.name, error: error);
      await FallbackSystemFeedback().beep(kind);
    }
  }
}

class FallbackSystemFeedback implements SystemFeedback {
  @override
  Future<void> haptic(HapticKind kind) async {
    switch (kind) {
      case HapticKind.tap:
        await HapticFeedback.lightImpact();
      case HapticKind.success:
        await HapticFeedback.mediumImpact();
      case HapticKind.error:
        await HapticFeedback.heavyImpact();
      case HapticKind.connection:
        await HapticFeedback.mediumImpact();
      case HapticKind.capture:
        await HapticFeedback.heavyImpact();
    }
  }

  @override
  Future<void> beep(HapticKind kind) async {
    await SystemSound.play(
      kind == HapticKind.error ? SystemSoundType.alert : SystemSoundType.click,
    );
  }
}

class GlassesChannels {
  GlassesChannels({MethodChannel? methods, EventChannel? events})
    : methods = methods ?? const MethodChannel(GlassesProtocol.methodChannel),
      events = events ?? const EventChannel(GlassesProtocol.eventChannel);

  final MethodChannel methods;
  final EventChannel events;
}
