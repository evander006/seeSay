import 'package:flutter_test/flutter_test.dart';
import 'package:seesay/core/accessibility/accessibility_audio_service.dart';
import 'package:seesay/core/accessibility/speech_use_cases.dart';
import 'package:seesay/core/accessibility/tts_engine.dart';
import 'package:seesay/core/events/recorded_event.dart';
import 'package:seesay/core/logging/app_logger.dart';
import 'package:seesay/features/events/domain/glasses_event_repository.dart';
import 'package:seesay/features/events/presentation/events_cubit.dart';

void main() {
  test('speaks recognized text and acknowledges it once', () async {
    final engine = MockTtsEngine();
    final audio = AccessibilityAudioService(engine: engine, logger: AppLogger());
    final repository = MemoryGlassesEventRepository();
    final cubit = EventsCubit(
      repository: repository,
      speakText: SpeakText(audio),
    );
    await repository.startMonitoring();
    await cubit.trigger(RecordedEventType.textRecognized);
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    expect(engine.spoken, ['На табличке написано: Выход к платформам направо']);
    expect(await repository.pending(), isEmpty);
    expect(cubit.state.events, hasLength(1));

    await cubit.trigger(RecordedEventType.batteryChanged);
    await Future<void>.delayed(Duration.zero);
    expect(engine.spoken, hasLength(1));
    await cubit.close();
  });

  test('reports when monitoring is off', () async {
    final engine = MockTtsEngine();
    final audio = AccessibilityAudioService(engine: engine, logger: AppLogger());
    final cubit = EventsCubit(
      repository: MemoryGlassesEventRepository(),
      speakText: SpeakText(audio),
    );
    await cubit.trigger(RecordedEventType.textRecognized);
    expect(cubit.state.error, 'Сначала включите фоновый мониторинг.');
    await cubit.close();
  });
}
