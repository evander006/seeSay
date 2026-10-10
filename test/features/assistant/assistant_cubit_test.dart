import 'package:flutter_test/flutter_test.dart';
import 'package:seesay/core/accessibility/accessibility_audio_service.dart';
import 'package:seesay/core/accessibility/speech_use_cases.dart';
import 'package:seesay/core/accessibility/tts_engine.dart';
import 'package:seesay/core/logging/app_logger.dart';
import 'package:seesay/core/storage/response_storage.dart';
import 'package:seesay/features/assistant/domain/ai_assistant_repository.dart';
import 'package:seesay/features/assistant/presentation/assistant_cubit.dart';
import 'package:seesay/features/events/domain/glasses_event_repository.dart';

class _ToggleAssistant implements AiAssistantRepository {
  _ToggleAssistant(this.fail);

  bool fail;

  @override
  Future<AssistantReply> reply(String prompt) async {
    if (fail) throw StateError('сеть');
    return AssistantReply(
      text: 'Демонстрационный ответ. Вы написали: $prompt',
      simulated: true,
    );
  }
}

void main() {
  test('mock reply is marked simulated', () async {
    const assistant = MockAiAssistantRepository();
    final reply = await assistant.reply('  привет  ');
    expect(reply.simulated, isTrue);
    expect(reply.text, 'Демонстрационный ответ. Вы написали: привет');
  });

  test('chat shows loading, error, and a successful retry', () async {
    final engine = MockTtsEngine();
    final audio = AccessibilityAudioService(engine: engine, logger: AppLogger());
    final assistant = _ToggleAssistant(true);
    final cubit = AssistantCubit(
      assistant: assistant,
      events: MemoryGlassesEventRepository(),
      speakText: SpeakText(audio),
      stopSpeech: StopSpeech(audio),
      repeatLast: RepeatLastResponse(
        storage: MemoryResponseStorage(),
        audio: audio,
      ),
      describe: () async => const AssistantReply(text: 'сцена', simulated: true),
      readText: () async => const AssistantReply(text: 'текст', simulated: true),
    );

    final pending = cubit.send('вопрос');
    expect(cubit.state.loading, isTrue);
    await pending;
    expect(cubit.state.loading, isFalse);
    expect(cubit.state.error, contains('сеть'));

    assistant.fail = false;
    await cubit.retry();
    expect(cubit.state.error, isNull);
    expect(
      cubit.state.messages.last.text,
      'Демонстрационный ответ. Вы написали: вопрос',
    );
    expect(cubit.state.messages.last.simulated, isTrue);
    expect(engine.spoken, ['Демонстрационный ответ. Вы написали: вопрос']);

    await cubit.stop();
    expect(engine.stopCount, greaterThan(0));
    await cubit.close();
  });
}
