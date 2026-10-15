import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

abstract class SettingsStore {
  Future<void> init();

  double get speechRate;

  Future<void> setSpeechRate(double value);

  String get language;

  Future<void> setLanguage(String value);

  bool get customTouchSpeech;

  Future<void> setCustomTouchSpeech(bool value);

  String? get lastDeviceAddress;

  Future<void> setLastDeviceAddress(String? value);

  String get lastConnectionState;

  Future<void> setLastConnectionState(String value);

  /// Server chosen in Settings; null means the build default.
  String? get backendUrl;

  Future<void> setBackendUrl(String value);

  /// Stable random id of this installation, sent to the server as X-Device-Id.
  Future<String> deviceId();
}

class SharedPrefsSettingsStore implements SettingsStore {
  SharedPreferences? _prefs;

  @override
  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  @override
  double get speechRate => _prefs?.getDouble('speech_rate') ?? 1;

  @override
  Future<void> setSpeechRate(double value) {
    return _prefs!.setDouble('speech_rate', value);
  }

  @override
  String get language => _prefs?.getString('language') ?? 'ru-RU';

  @override
  Future<void> setLanguage(String value) {
    return _prefs!.setString('language', value);
  }

  @override
  bool get customTouchSpeech => _prefs?.getBool('custom_touch_speech') ?? true;

  @override
  Future<void> setCustomTouchSpeech(bool value) {
    return _prefs!.setBool('custom_touch_speech', value);
  }

  @override
  String? get lastDeviceAddress => _prefs?.getString('last_device_address');

  @override
  Future<void> setLastDeviceAddress(String? value) {
    if (value == null || value.isEmpty) {
      return _prefs!.remove('last_device_address');
    }
    return _prefs!.setString('last_device_address', value);
  }

  @override
  String get lastConnectionState =>
      _prefs?.getString('last_connection_state') ?? 'disconnected';

  @override
  Future<void> setLastConnectionState(String value) {
    return _prefs!.setString('last_connection_state', value);
  }

  @override
  String? get backendUrl => _prefs?.getString('backend_url');

  @override
  Future<void> setBackendUrl(String value) {
    return _prefs!.setString('backend_url', value);
  }

  @override
  Future<String> deviceId() async {
    final saved = _prefs?.getString('device_id');
    if (saved != null && saved.isNotEmpty) return saved;
    final created = newDeviceId();
    await _prefs!.setString('device_id', created);
    return created;
  }
}

/// `seesay-` + 16 random hex characters.
String newDeviceId() {
  final random = Random.secure();
  final hex = List.generate(8, (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'));
  return 'seesay-${hex.join()}';
}

class MemorySettingsStore implements SettingsStore {
  double _speechRate = 1;
  String _language = 'ru-RU';
  bool _customTouchSpeech = true;
  String? _lastDeviceAddress;
  String _lastConnectionState = 'disconnected';
  String? _backendUrl;

  @override
  Future<void> init() async {}

  @override
  double get speechRate => _speechRate;

  @override
  Future<void> setSpeechRate(double value) async {
    _speechRate = value;
  }

  @override
  String get language => _language;

  @override
  Future<void> setLanguage(String value) async {
    _language = value;
  }

  @override
  bool get customTouchSpeech => _customTouchSpeech;

  @override
  Future<void> setCustomTouchSpeech(bool value) async {
    _customTouchSpeech = value;
  }

  @override
  String? get lastDeviceAddress => _lastDeviceAddress;

  @override
  Future<void> setLastDeviceAddress(String? value) async {
    _lastDeviceAddress = value;
  }

  @override
  String get lastConnectionState => _lastConnectionState;

  @override
  Future<void> setLastConnectionState(String value) async {
    _lastConnectionState = value;
  }

  @override
  String? get backendUrl => _backendUrl;

  @override
  Future<void> setBackendUrl(String value) async {
    _backendUrl = value;
  }

  final String _deviceId = newDeviceId();

  @override
  Future<String> deviceId() async => _deviceId;
}
