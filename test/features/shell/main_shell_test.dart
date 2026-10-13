import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seesay/app/di/injection.dart';
import 'package:seesay/app/theme/app_theme.dart';
import 'package:seesay/core/accessibility/speech_use_cases.dart';
import 'package:seesay/core/events/recorded_event.dart';
import 'package:seesay/features/assistant/domain/ai_assistant_repository.dart';
import 'package:seesay/features/assistant/presentation/assistant_cubit.dart';
import 'package:seesay/features/events/domain/glasses_event_repository.dart';
import 'package:seesay/features/gallery/presentation/gallery_cubit.dart';
import 'package:seesay/features/home/presentation/app_scope.dart';
import 'package:seesay/features/shell/main_shell.dart';
import 'package:seesay/features/vision/presentation/vision_cubit.dart';

import '../../support/fakes.dart';
import '../../support/home_harness.dart';

void main() {
  late HomeHarness harness;

  setUp(() {
    harness = HomeHarness();
    getIt.registerFactory(
      () => AssistantCubit(
        assistant: const MockAiAssistantRepository(),
        events: MemoryGlassesEventRepository(),
        speakText: SpeakText(harness.audio),
        stopSpeech: StopSpeech(harness.audio),
        repeatLast: RepeatLastResponse(
          storage: harness.storage,
          audio: harness.audio,
        ),
        describe: () async =>
            const AssistantReply(text: 'сцена', simulated: true),
        readText: () async =>
            const AssistantReply(text: 'текст', simulated: true),
      ),
    );
    getIt.registerFactory(
      () => GalleryCubit(
        storage: harness.storage,
        speakText: SpeakText(harness.audio),
      ),
    );
  });

  tearDown(() async {
    await getIt.reset();
    await harness.dispose();
  });

  testWidgets('switches four destinations and shows mock chat', (tester) async {
    await tester.pumpWidget(_shell(harness));
    await tester.pump();

    expect(find.text('Главная'), findsOneWidget);
    expect(find.text('AI-помощник'), findsOneWidget);
    expect(find.text('Галерея'), findsOneWidget);
    expect(find.text('Профиль'), findsOneWidget);
    expect(find.text('Очки не подключены'), findsOneWidget);
    expect(
      find.text('Значения имитации не приходят с очков.'),
      findsOneWidget,
    );

    await tester.tap(find.text('Галерея'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Снимков пока нет'), findsOneWidget);

    await tester.tap(find.text('AI-помощник'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'привет');
    await tester.tap(find.byTooltip('Отправить'));
    await tester.pump();
    await tester.pump();
    expect(find.textContaining('Демонстрационный ответ'), findsOneWidget);
    expect(find.textContaining('имитация'), findsWidgets);
  });

  testWidgets('shows a stored mock event on the profile tab', (tester) async {
    await tester.pumpWidget(_shell(harness));
    await tester.pump();
    await tester.tap(find.text('Профиль'));
    await tester.pumpAndSettle();
    expect(
      find.text('Событий пока нет.', skipOffstage: false),
      findsOneWidget,
    );

    await harness.events.setMonitoring(true);
    await harness.events.trigger(RecordedEventType.textRecognized);
    await tester.pump();
    await tester.pump();
    expect(
      find.text('Событий пока нет.', skipOffstage: false),
      findsNothing,
    );
    expect(
      find.textContaining('имитация ·', skipOffstage: false),
      findsOneWidget,
    );
  });
}

Widget _shell(HomeHarness harness) {
  return MaterialApp(
    theme: AppTheme.light,
    home: AppScope(
      audio: harness.audio,
      feedback: QuietFeedback(),
      repeatLast: () async {},
      child: MultiBlocProvider(
        providers: [
          BlocProvider.value(value: harness.appCubit),
          BlocProvider.value(value: harness.connection),
          BlocProvider<VisionCubit>.value(value: harness.vision),
          BlocProvider.value(value: harness.ocr),
          BlocProvider.value(value: harness.accessibility),
          BlocProvider.value(value: harness.events),
        ],
        child: const MainShell(),
      ),
    ),
  );
}
