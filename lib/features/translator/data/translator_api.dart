import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:seesay/core/network/api_client.dart';

/// Result of one phrase (backend: src/api/v1/translate.py).
class TranslatedPhrase {
  const TranslatedPhrase({
    required this.lang,
    required this.text,
    required this.translation,
    required this.to,
    this.audio,
  });

  /// Language of the phrase (ISO 639-1); `ru` means the user spoke.
  final String lang;
  final String text;
  final String translation;
  final String to;

  /// MP3 for the partner, only when the user spoke.
  final List<int>? audio;

  bool get fromUser => lang == 'ru';
}

class TranslatorApi {
  TranslatorApi(this._client);

  /// Resolved on first use: the server address may change in settings.
  final ApiClient Function() _client;

  Future<TranslatedPhrase?> phrase(File wav, {required String partner}) async {
    final response = await _client().dio.post<ResponseBody>(
      '/api/v1/translate/phrase',
      data: FormData.fromMap({
        'audio': MultipartFile.fromFileSync(
          wav.path,
          filename: 'phrase.wav',
          contentType: DioMediaType('audio', 'wav'),
        ),
        'partner': partner,
      }),
      options: Options(
        responseType: ResponseType.stream,
        receiveTimeout: const Duration(seconds: 25),
      ),
    );
    String? lang;
    String text = '';
    String translation = '';
    String to = '';
    List<int>? audio;
    final lines = response.data!.stream
        .cast<List<int>>()
        .transform(utf8.decoder)
        .transform(const LineSplitter());
    await for (final line in lines) {
      if (line.trim().isEmpty) continue;
      final event = jsonDecode(line) as Map<String, dynamic>;
      switch (event['type']) {
        case 'text':
          lang = event['lang'] as String? ?? '?';
          text = (event['text'] as String? ?? '').trim();
          translation = (event['translation'] as String? ?? '').trim();
          to = event['to'] as String? ?? '';
        case 'audio':
          audio = base64Decode(event['data'] as String);
        case 'error':
          throw StateError(event['text'] as String? ?? 'Не удалось перевести.');
      }
    }
    if (lang == null) return null;
    return TranslatedPhrase(lang: lang, text: text, translation: translation, to: to, audio: audio);
  }

  /// Wakes the server's voice synthesis up: its first call is ~5 s, later ones ~1 s.
  Future<void> warm() async {
    try {
      await _client().dio.post<void>('/api/v1/translate/warm');
    } on Object {
      // Only a speed-up.
    }
  }
}
