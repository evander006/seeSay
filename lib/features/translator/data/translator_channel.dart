import 'package:flutter/services.dart';

/// Bridge to the Android interpreter (translator/TranslatorEngine.kt); separate from the glasses one.
class TranslatorChannel {
  TranslatorChannel({MethodChannel? methods, EventChannel? events})
    : _methods = methods ?? const MethodChannel('com.example.seesay/translator'),
      _events = events ?? const EventChannel('com.example.seesay/translator_events');

  final MethodChannel _methods;
  final EventChannel _events;
  Stream<Map<String, dynamic>>? _shared;

  /// level {rms, speaking}, speech {state}, phrase {path, ms}, error {text}.
  Stream<Map<String, dynamic>> events() {
    return _shared ??= _events
        .receiveBroadcastStream()
        .map((raw) => Map<String, dynamic>.from(raw as Map))
        .asBroadcastStream();
  }

  /// Starts listening with the phone mic; throws with a message for the user.
  Future<void> start() async {
    try {
      await _methods.invokeMethod<bool>('start');
    } on PlatformException catch (error) {
      throw StateError(error.message ?? 'Не удалось включить микрофон.');
    }
  }

  Future<void> stop() => _methods.invokeMethod<void>('stop');

  /// Russian text into the glasses; completes when it has been said.
  Future<bool> speakToGlasses(String text) async {
    return await _methods.invokeMethod<bool>('speakToGlasses', {'text': text}) ?? false;
  }

  /// MP3 file on the phone speaker (for the partner); completes when it has been played.
  Future<bool> playOnSpeaker(String path) async {
    return await _methods.invokeMethod<bool>('playOnSpeaker', {'path': path}) ?? false;
  }
}
