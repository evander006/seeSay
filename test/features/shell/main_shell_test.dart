import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seesay/app/di/injection.dart';
import 'package:seesay/app/theme/app_theme.dart';
import 'package:seesay/core/accessibility/speech_use_cases.dart';
import 'package:seesay/core/permissions/permission_service.dart';
import 'package:seesay/core/platform/background_access.dart';
import 'package:seesay/core/platform/glasses_channel.dart';
import 'package:seesay/features/assistant/presentation/assistant_cubit.dart';
import 'package:seesay/features/gallery/presentation/gallery_cubit.dart';
import 'package:seesay/features/shell/main_shell.dart';

import '../../support/fakes.dart';
import '../../support/home_harness.dart';

void main() {
  late HomeHarness harness;

  setUp(() {
    harness = HomeHarness();
    getIt
      ..registerSingleton<PermissionService>(AllowAllPermissions())
      ..registerSingleton<BackgroundAccess>(BackgroundAccess(GlassesChannel()))
      ..registerFactory(
        () => AssistantCubit(
          storage: harness.storage,
          stopSpeech: StopSpeech(harness.audio),
          repeatLast: RepeatLastResponse(
            storage: harness.storage,
            audio: harness.audio,
          ),
          ask: (_) async {},
          describe: () async {},
          readText: () async {},
        ),
      )
      ..registerFactory(
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

  testWidgets('switches the four tabs', (tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: harness.wrap(const MainShell()),
      ),
    );
    await tester.pump();

    for (final label in ['Главная', 'Помощник', 'Галерея', 'Перевод', 'Настройки']) {
      expect(find.text(label), findsOneWidget);
    }
    expect(find.text('Очки не подключены'), findsOneWidget);

    await tester.tap(find.text('Галерея'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Снимков пока нет'), findsOneWidget);

    await tester.tap(find.text('Помощник'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Здесь будут ваши вопросы'), findsOneWidget);

    await tester.tap(find.text('Перевод'));
    await tester.pumpAndSettle();
    expect(find.text('Начать перевод'), findsOneWidget);

    await tester.tap(find.text('Настройки'));
    await tester.pumpAndSettle();
    expect(find.text('Проверить и сохранить'), findsOneWidget);
    expect(find.text('Работа в фоне'), findsOneWidget);
  });
}
