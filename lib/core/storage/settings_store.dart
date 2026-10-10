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
}

class MemorySettingsStore implements SettingsStore {
  double _speechRate = 1;
  String _language = 'ru-RU';
  bool _customTouchSpeech = true;
  String? _lastDeviceAddress;
  String _lastConnectionState = 'disconnected';

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
}
