import 'package:seesay/core/accessibility/accessibility_audio_queue.dart';
import 'package:seesay/core/accessibility/accessibility_audio_service.dart';
import 'package:seesay/core/accessibility/speech_messages.dart';
import 'package:seesay/core/storage/response_storage.dart';

class SpeakText {
  SpeakText(this._audio);

  final AccessibilityAudioService _audio;

  Future<void> call(
    String text, {
    SpeechPriority priority = SpeechPriority.normal,
    bool interrupt = false,
    SpeechKind kind = SpeechKind.status,
  }) {
    return _audio.speak(
      text,
      priority: priority,
      interrupt: interrupt,
      kind: kind,
    );
  }
}

class StopSpeech {
  StopSpeech(this._audio);

  final AccessibilityAudioService _audio;

  Future<void> call() => _audio.stop();
}

class RepeatLastResponse {
  RepeatLastResponse({required this._storage, required this._audio});

  final ResponseStorage _storage;
  final AccessibilityAudioService _audio;

  Future<void> call() async {
    final items = await _storage.getAll();
    if (items.isEmpty) {
      await _audio.speak(
        SpeechMessages.noSavedResponse,
        priority: SpeechPriority.low,
        interrupt: true,
        kind: SpeechKind.response,
      );
      return;
    }
    await _audio.speak(
      items.first.text,
      priority: SpeechPriority.high,
      interrupt: true,
      kind: SpeechKind.response,
    );
  }
}
