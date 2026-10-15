import 'package:flutter/services.dart';

import 'package:seesay/core/config/dotenv.dart';

/// Build-time defaults. The server address can be changed later in Settings.
class AppConfig {
  const AppConfig({required this.apiBaseUrl});

  /// Server used until the user saves another one in Settings.
  final String apiBaseUrl;

  static const defaults = AppConfig(apiBaseUrl: 'http://10.0.2.2:8000');

  static Future<AppConfig> load() async {
    var values = const <String, String>{};
    try {
      values = DotEnv.parse(await rootBundle.loadString('.env'));
    } on Object {
      values = const {};
    }
    const defineUrl = String.fromEnvironment('API_BASE_URL');
    return AppConfig(
      apiBaseUrl: defineUrl.isNotEmpty
          ? defineUrl
          : (values['API_BASE_URL'] ?? defaults.apiBaseUrl),
    );
  }
}
