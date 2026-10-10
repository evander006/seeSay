import 'package:seesay/core/accessibility/accessibility_audio_queue.dart';
import 'package:seesay/core/accessibility/tts_engine.dart';
import 'package:seesay/core/errors/app_exception.dart';
import 'package:seesay/core/logging/app_logger.dart';

class AccessibilityAudioService {
  AccessibilityAudioService({required this._engine, required this._logger}) {
    _queue = AccessibilityAudioQueue(speak: _speakOnEngine, stop: _engine.stop);
  }

  final TtsEngine _engine;
  final AppLogger _logger;
  late final AccessibilityAudioQueue _queue;

  double _rate = 1;
  String _language = 'ru-RU';
  String? lastResponse;

  double get speechRate => _rate;

  String get language => _language;

  Future<void> setSpeechRate(double rate) async {
    _rate = rate.clamp(0.5, 2.0);
    await _engine.setSpeechRate(_rate);
  }

  Future<void> setLanguage(String language) async {
    _language = language;
    await _engine.setLanguage(language);
  }

  Future<void> speak(
    String text, {
    SpeechPriority priority = SpeechPriority.normal,
    bool interrupt = false,
    SpeechKind kind = SpeechKind.status,
  }) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    if (kind == SpeechKind.response) lastResponse = trimmed;

    try {
      await _queue.enqueue(
        SpeechRequest(
          text: trimmed,
          priority: priority,
          interrupt:
              interrupt ||
              priority == SpeechPriority.high ||
              priority == SpeechPriority.critical,
        ),
      );
    } on SpeechException {
      rethrow;
    } on Object catch (error) {
      _logger.error('TTS error', action: kind.name, error: error);
      throw SpeechException('Не удалось озвучить ответ.');
    }
  }

  Future<void> stop() => _queue.clear();

  Future<void> repeatLast() {
    final text = lastResponse;
    if (text == null || text.isEmpty) {
      return speak(
        'Нет сохранённого ответа.',
        priority: SpeechPriority.low,
        interrupt: true,
        kind: SpeechKind.response,
      );
    }
    return speak(
      text,
      priority: SpeechPriority.high,
      interrupt: true,
      kind: SpeechKind.response,
    );
  }

  Future<void> dispose() async {
    await stop();
    await _engine.dispose();
  }

  Future<void> _speakOnEngine(String text) async {
    _logger.info('TTS started', action: 'speak');
    try {
      await _engine.speak(text, rate: _rate, language: _language);
      _logger.info('TTS finished', action: 'speak');
    } on Object catch (error) {
      _logger.error('TTS error', action: 'speak', error: error);
      throw SpeechException('Не удалось озвучить ответ.');
    }
  }
}
