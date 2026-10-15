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
    this.detail,
  });

  final ConnectionStatus status;
  final String? message;
  final String? deviceAddress;
  final int? battery;

  /// Progress or failure report of the glasses search, shown on screen (not spoken).
  final String? detail;
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

/// A glasses button over BLE: red (photo button, once per press) or black (assistant).
class GlassesButtonPressed extends GlassesEvent {
  const GlassesButtonPressed(this.button, this.kind);

  final String button;

  /// `press` or `double` (black pressed twice: the glasses send a photo themselves).
  final String kind;
}

/// The glasses listen to the question (`listening`) or gave up without voice (`idle`).
class VoiceStateChanged extends GlassesEvent {
  const VoiceStateChanged(this.state, this.reason);

  final String state;
  final String? reason;
}

/// The question recorded by the glasses mic: Opus packets `[u16 length][packet]…` in [path].
class VoiceCaptured extends GlassesEvent {
  const VoiceCaptured({
    required this.path,
    required this.packets,
    required this.durationMs,
    required this.reason,
  });

  final String path;
  final int packets;
  final int durationMs;
  final String reason;
}

/// A JPEG from the glasses camera that came over BLE. [reason]: voice, recognition, request.
class GlassesPhotoReceived extends GlassesEvent {
  const GlassesPhotoReceived(this.path, this.reason, this.waitedMs);

  final String path;
  final String reason;
  final int waitedMs;
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

  /// Takes a photo with the phone's back camera; returns the JPEG path.
  Future<String> capturePhoto() async {
    try {
      final path = await _methods.invokeMethod<String>(
        GlassesProtocol.capturePhoto,
      );
      if (path == null || path.isEmpty) {
        throw CameraException('Камера не вернула снимок.');
      }
      return path;
    } on MissingPluginException {
      throw CameraException('Камера недоступна.');
    } on PlatformException catch (error) {
      throw CameraException(error.message ?? 'Камера недоступна.');
    }
  }

  /// Asks the glasses for a photo over BLE; it arrives as [GlassesPhotoReceived].
  Future<bool> requestGlassesPhoto({String reason = 'request'}) async {
    final value = await _methods.invokeMethod<bool>(
      GlassesProtocol.requestGlassesPhoto,
      {'reason': reason},
    );
    return value ?? false;
  }

  /// Plays the competitors pitch at full volume; completes when it ends.
  Future<bool> playPitch() async {
    final value = await _methods.invokeMethod<bool>(GlassesProtocol.playPitch);
    return value ?? false;
  }

  Future<void> stopPitch() => _invoke(GlassesProtocol.stopPitch);

  /// Line for the app's diagnostic log file (Android side keeps ~2 MB).
  Future<void> diagLog(String level, String message) async {
    try {
      await _methods.invokeMethod<void>(GlassesProtocol.diagLog, {
        'level': level,
        'message': message,
      });
    } on Object {
      // Logging must never break the app.
    }
  }

  /// Path of the whole diagnostic log glued into one file.
  Future<String?> exportLog() =>
      _methods.invokeMethod<String>(GlassesProtocol.exportLog);

  /// Walking route in Yandex Maps; false when Android did not let it open.
  Future<bool> openRoute({
    required double lat,
    required double lon,
    double? fromLat,
    double? fromLon,
  }) async {
    try {
      final value = await _methods.invokeMethod<bool>(GlassesProtocol.openRoute, {
        'lat': lat,
        'lon': lon,
        'fromLat': fromLat,
        'fromLon': fromLon,
      });
      return value ?? false;
    } on Object {
      return false;
    }
  }

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

  /// True when Android battery optimisation does not restrict SeeSay.
  Future<bool> isBackgroundUnrestricted() async {
    try {
      final value = await _methods.invokeMethod<bool>(
        GlassesProtocol.isBackgroundUnrestricted,
      );
      return value ?? false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  /// Opens the system dialog that lets SeeSay always run in the background.
  Future<void> requestBackgroundUnrestricted() {
    return _invoke(GlassesProtocol.requestBackgroundUnrestricted);
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
