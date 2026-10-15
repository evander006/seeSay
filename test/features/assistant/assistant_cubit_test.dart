import 'package:flutter_test/flutter_test.dart';
import 'package:seesay/core/accessibility/accessibility_audio_service.dart';
import 'package:seesay/core/accessibility/speech_use_cases.dart';
import 'package:seesay/core/logging/app_logger.dart';
import 'package:seesay/core/storage/response_storage.dart';
import 'package:seesay/core/storage/saved_response.dart';
import 'package:seesay/features/assistant/presentation/assistant_cubit.dart';

import '../../support/fakes.dart';

void main() {
  late MemoryResponseStorage storage;
  late AssistantCubit cubit;
  var fail = false;
  final asked = <String>[];

  Future<void> answer(String? prompt, ResponseType type) async {
    if (fail) throw StateError('Сервер не отвечает.');
    if (prompt != null) asked.add(prompt);
    final now = DateTime.now();
    await storage.add(
      SavedResponse(
        id: now.microsecondsSinceEpoch.toString(),
        text: 'Ответ на ${prompt ?? type.name}',
        createdAt: now,
        type: type,
        prompt: prompt,
      ),
    );
  }

  setUp(() {
    fail = false;
    asked.clear();
    storage = MemoryResponseStorage();
    final audio = AccessibilityAudioService(
      engine: MockTtsEngine(),
      logger: AppLogger(),
    );
    cubit = AssistantCubit(
      storage: storage,
      stopSpeech: StopSpeech(audio),
      repeatLast: RepeatLastResponse(storage: storage, audio: audio),
      ask: (prompt) => answer(prompt, ResponseType.scene),
      describe: () => answer(null, ResponseType.scene),
      readText: () => answer(null, ResponseType.ocr),
    );
  });

  tearDown(() => cubit.close());

  test('a question goes to the server and shows as a pair of lines', () async {
    await cubit.send('Что на табличке?');

    expect(asked, ['Что на табличке?']);
    expect(cubit.state.loading, isFalse);
    expect(cubit.state.messages.map((line) => line.text), [
      'Что на табличке?',
      'Ответ на Что на табличке?',
    ]);
  });

  test('glasses answers saved elsewhere appear in the chat', () async {
    await answer(null, ResponseType.ocr);
    await pumpEventQueue();

    expect(cubit.state.messages.first.text, AssistantCubit.readPrompt);
    expect(cubit.state.messages.last.fromUser, isFalse);
  });

  test('an error is shown and retry repeats the question', () async {
    fail = true;
    await cubit.send('Где выход?');
    expect(cubit.state.error, 'Сервер не отвечает.');
    expect(cubit.state.messages, isEmpty);

    fail = false;
    await cubit.retry();
    expect(cubit.state.error, isNull);
    expect(asked, ['Где выход?']);
  });
}
