import 'package:flutter/services.dart';

import 'package:seesay/core/config/dotenv.dart';

class AppConfig {
  const AppConfig({
    required this.apiBaseUrl,
    required this.useMockGlasses,
    required this.useMockApi,
    required this.useMockCamera,
    required this.useMockTts,
  });

  final String apiBaseUrl;
  final bool useMockGlasses;
  final bool useMockApi;
  final bool useMockCamera;
  final bool useMockTts;

  static const defaults = AppConfig(
    apiBaseUrl: 'http://10.0.2.2:8000',
    useMockGlasses: true,
    useMockApi: true,
    useMockCamera: false,
    useMockTts: false,
  );

  static Future<AppConfig> load() async {
    var values = const <String, String>{};
    try {
      values = DotEnv.parse(await rootBundle.loadString('.env'));
    } on Object {
      values = const {};
    }

    const defineUrl = String.fromEnvironment('API_BASE_URL');
    const defineGlasses = String.fromEnvironment('USE_MOCK_GLASSES');
    const defineApi = String.fromEnvironment('USE_MOCK_API');
    const defineCamera = String.fromEnvironment('USE_MOCK_CAMERA');
    const defineTts = String.fromEnvironment('USE_MOCK_TTS');

    return AppConfig(
      apiBaseUrl: defineUrl.isNotEmpty
          ? defineUrl
          : (values['API_BASE_URL'] ?? defaults.apiBaseUrl),
      useMockGlasses: _bool(
        defineGlasses,
        values['USE_MOCK_GLASSES'],
        fallback: true,
      ),
      useMockApi: _bool(defineApi, values['USE_MOCK_API'], fallback: true),
      useMockCamera: _bool(
        defineCamera,
        values['USE_MOCK_CAMERA'],
        fallback: false,
      ),
      useMockTts: _bool(defineTts, values['USE_MOCK_TTS'], fallback: false),
    );
  }

  static bool _bool(
    String fromDefine,
    String? fromFile, {
    required bool fallback,
  }) {
    final raw = fromDefine.isNotEmpty ? fromDefine : fromFile;
    if (raw == null || raw.isEmpty) return fallback;
    return raw.toLowerCase() == 'true' || raw == '1';
  }
}
