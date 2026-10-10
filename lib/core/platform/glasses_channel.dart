import 'dart:async';

import 'package:flutter/services.dart';
import 'package:seesay/core/accessibility/tts_engine.dart';
import 'package:seesay/core/bluetooth/ble_packet.dart';
import 'package:seesay/core/errors/app_exception.dart';
import 'package:seesay/core/platform/glasses_protocol.dart';

enum MediaButtonAction { playPause, volumeUp, volumeDown, unknown }

enum ConnectionStatus { disconnected, connecting, reconnecting, connected, error }

class GlassesSnapshot {
  const GlassesSnapshot({
    this.status = ConnectionStatus.disconnected,
    this.message,
    this.deviceAddress,
    this.battery,
  });

  final ConnectionStatus status;
  final String? message;
  final String? deviceAddress;
  final int? battery;
}

sealed class GlassesEvent {
  const GlassesEvent();
}

class ConnectionChanged extends GlassesEvent {
  const ConnectionChanged(this.snapshot);

  final GlassesSnapshot snapshot;
}

class BlePacketReceived extends GlassesEvent {
  const BlePacketReceived(this.packet);

  final BlePacket packet;
}

class MediaButtonReceived extends GlassesEvent {
  const MediaButtonReceived(this.action);

  final MediaButtonAction action;
}

class BatteryChanged extends GlassesEvent {
  const BatteryChanged(this.level);

  final int level;
}

class GlassesChannel {
  GlassesChannel({MethodChannel? methods, EventChannel? events})
    : _methods = methods ?? const MethodChannel(GlassesProtocol.methodChannel),
      _events = events ?? const EventChannel(GlassesProtocol.eventChannel);

  final MethodChannel _methods;
  final EventChannel _events;

  MethodChannel get methods => _methods;

  Stream<Map<String, dynamic>>? _sharedEvents;

  Stream<Map<String, dynamic>> events() {
    return _sharedEvents ??= _events.receiveBroadcastStream().map((raw) {
      return Map<String, dynamic>.from(raw as Map);
    }).asBroadcastStream();
  }

  Future<void> connect(String? deviceAddress) {
    return _invoke(GlassesProtocol.connectGlasses, {
      'deviceAddress': deviceAddress,
    });
  }

  Future<void> disconnect() => _invoke(GlassesProtocol.disconnectGlasses);

  Future<void> startCapture() => _invoke(GlassesProtocol.startCapture);

  Future<void> stopCapture() => _invoke(GlassesProtocol.stopCapture);

  Future<String> connectionState() async {
    final value = await _methods.invokeMethod<String>(
      GlassesProtocol.getConnectionState,
    );
    return value ?? ConnectionStatus.disconnected.name;
  }

  Future<bool> isBluetoothEnabled() async {
    final value = await _methods.invokeMethod<bool>(
      GlassesProtocol.isBluetoothEnabled,
    );
    return value ?? false;
  }

  Future<void> speak({
    required String text,
    required double rate,
    required String language,
  }) {
    return _invoke(GlassesProtocol.speak, {
      'text': text,
      'rate': rate,
      'language': language,
    });
  }

  Future<void> stopSpeaking() => _invoke(GlassesProtocol.stopSpeaking);

  Future<void> setSpeechRate(double rate) {
    return _invoke(GlassesProtocol.setSpeechRate, {'rate': rate});
  }

  Future<void> setLanguage(String language) {
    return _invoke(GlassesProtocol.setLanguage, {'language': language});
  }

  Future<void> startBackgroundMonitoring() {
    return _invoke(GlassesProtocol.startBackgroundMonitoring);
  }

  Future<void> stopBackgroundMonitoring() {
    return _invoke(GlassesProtocol.stopBackgroundMonitoring);
  }

  Future<bool> backgroundMonitoringStatus() async {
    try {
      final value = await _methods.invokeMethod<bool>(
        GlassesProtocol.getBackgroundMonitoringStatus,
      );
      return value ?? false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  Future<void> enableMockMode() => _invoke(GlassesProtocol.enableMockMode);

  Future<void> disableMockMode() => _invoke(GlassesProtocol.disableMockMode);

  Future<void> triggerMockEvent(String type) {
    return _invoke(GlassesProtocol.triggerMockEvent, {'type': type});
  }

  Future<List<Map<String, dynamic>>> pendingGlassesEvents() {
    return _eventList(GlassesProtocol.getPendingGlassesEvents);
  }

  Future<List<Map<String, dynamic>>> recentGlassesEvents() {
    return _eventList(GlassesProtocol.getRecentGlassesEvents);
  }

  Future<void> acknowledgeGlassesEvent(String eventId) {
    return _invoke(GlassesProtocol.acknowledgeGlassesEvent, {
      'eventId': eventId,
    });
  }

  Future<List<Map<String, dynamic>>> _eventList(String method) async {
    try {
      final value = await _methods.invokeMethod<List<Object?>>(method);
      if (value == null) return const [];
      return value
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList(growable: false);
    } on MissingPluginException {
      return const [];
    } on PlatformException {
      return const [];
    }
  }

  Future<void> _invoke(String method, [Object? arguments]) async {
    try {
      await _methods.invokeMethod<void>(method, arguments);
    } on MissingPluginException {
      throw BluetoothException('Связь с Android недоступна.');
    } on PlatformException catch (error) {
      throw BluetoothException(error.message ?? 'Ошибка Android.');
    }
  }
}

class ChannelTtsEngine implements TtsEngine {
  ChannelTtsEngine(this._channel);

  final GlassesChannel _channel;

  @override
  Future<void> speak(
    String text, {
    required double rate,
    required String language,
  }) {
    return _channel.speak(text: text, rate: rate, language: language);
  }

  @override
  Future<void> stop() => _channel.stopSpeaking();

  @override
  Future<void> setSpeechRate(double rate) => _channel.setSpeechRate(rate);

  @override
  Future<void> setLanguage(String language) => _channel.setLanguage(language);

  @override
  Future<void> dispose() async {}
}

ConnectionStatus connectionStatusFromWire(String? raw) {
  return switch (raw) {
    'connecting' => ConnectionStatus.connecting,
    'reconnecting' => ConnectionStatus.reconnecting,
    'connected' => ConnectionStatus.connected,
    'error' => ConnectionStatus.error,
    _ => ConnectionStatus.disconnected,
  };
}

MediaButtonAction mediaButtonFromWire(String? raw) {
  return switch (raw) {
    'MEDIA_PLAY_PAUSE' => MediaButtonAction.playPause,
    'VOLUME_UP' => MediaButtonAction.volumeUp,
    'VOLUME_DOWN' => MediaButtonAction.volumeDown,
    _ => MediaButtonAction.unknown,
  };
}
