// Renders the main screens to PNG with real fonts, for a visual review without a phone:
//   flutter test test_screens/screens_test.dart --update-goldens
// Output: test_screens/out/*.png. Not part of the regular test suite.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seesay/app/di/injection.dart';
import 'package:seesay/app/theme/app_theme.dart';
import 'package:seesay/core/accessibility/speech_use_cases.dart';
import 'package:seesay/core/permissions/permission_service.dart';
import 'package:seesay/core/platform/background_access.dart';
import 'package:seesay/core/platform/glasses_channel.dart';
import 'package:seesay/core/storage/saved_response.dart';
import 'package:seesay/features/assistant/presentation/assistant_cubit.dart';
import 'package:seesay/features/gallery/presentation/gallery_cubit.dart';
import 'package:seesay/features/shell/main_shell.dart';
import 'package:seesay/features/vision/presentation/vision_cubit.dart';

import '../test/support/fakes.dart';
import '../test/support/home_harness.dart';

const _fonts = r'D:\dev\flutter\bin\cache\artifacts\material_fonts';
const _photos = [
  r'C:\Users\user\AppData\Local\Temp\claude\D--Work-Claude\2dd8c322-9308-4116-a126-3a99b1fb0bff\scratchpad\read_s.jpg',
  r'C:\Users\user\AppData\Local\Temp\claude\D--Work-Claude\2dd8c322-9308-4116-a126-3a99b1fb0bff\scratchpad\nav_s.jpg',
  r'C:\Users\user\AppData\Local\Temp\claude\D--Work-Claude\2dd8c322-9308-4116-a126-3a99b1fb0bff\scratchpad\mem_s.jpg',
];

Future<void> _loadFonts() async {
  Future<ByteData> read(String name) async =>
      ByteData.sublistView(await File('$_fonts\\$name').readAsBytes());
  final roboto = FontLoader('Roboto');
  for (final weight in ['regular', 'medium', 'bold', 'black']) {
    roboto.addFont(read('roboto-$weight.ttf'));
  }
  await roboto.load();
  await (FontLoader('MaterialIcons')..addFont(read('materialicons-regular.otf')))
      .load();
}

void main() {
  late HomeHarness harness;

  setUpAll(_loadFonts);

  setUp(() {
    harness = HomeHarness();
    getIt
      ..registerSingleton<PermissionService>(AllowAllPermissions())
      ..registerSingleton<BackgroundAccess>(BackgroundAccess(GlassesChannel()))
      ..registerFactory(
        () => AssistantCubit(
          storage: harness.storage,
          stopSpeech: StopSpeech(harness.audio),
          repeatLast: RepeatLastResponse(storage: harness.storage, audio: harness.audio),
          ask: (_) async {},
          describe: () async {},
          readText: () async {},
        ),
      )
      ..registerFactory(
        () => GalleryCubit(storage: harness.storage, speakText: SpeakText(harness.audio)),
      );
  });

  tearDown(() async {
    await getIt.reset();
    await harness.dispose();
  });

  Future<void> shoot(
    WidgetTester tester,
    String name, {
    Future<void> Function()? before,
    String? tab,
    Future<void> Function()? after,
  }) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.runAsync(() async => before?.call());
    await harness.backend.start();
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        home: harness.wrap(const MainShell()),
      ),
    );
    await tester.pump();
    if (tab != null) {
      await tester.tap(find.text(tab).last);
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
    }
    await tester.runAsync(() async {
      await after?.call();
      for (final element in find.byType(Image).evaluate()) {
        final image = (element.widget as Image).image;
        if (image is AssetImage) await precacheImage(image, element);
      }
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    for (var i = 0; i < 6; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 150)));
      await tester.pump(const Duration(milliseconds: 50));
    }
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('out/$name.png'));
  }

  Future<void> seed() async {
    final now = DateTime.now();
    final texts = [
      ('Что вокруг?', 'Перед вами пешеходный переход. Светофор зелёный, можно идти прямо.', ResponseType.scene),
      ('Прочитай текст', 'Томатный суп, 400 грамм. Годен до 12 ноября.', ResponseType.ocr),
      ('Кто это?', 'Это Анна, вы встречались на конференции ATOM в прошлом месяце.', ResponseType.scene),
    ];
    for (var i = 0; i < texts.length; i++) {
      final (prompt, text, type) = texts[i];
      await harness.storage.add(
        SavedResponse(
          id: '${now.microsecondsSinceEpoch + i}',
          text: text,
          createdAt: now.subtract(Duration(minutes: 30 - i * 9)),
          type: type,
          prompt: prompt == 'Что вокруг?' || prompt == 'Прочитай текст' ? null : prompt,
          imagePath: _photos[i],
        ),
      );
    }
  }

  testWidgets('01 home disconnected', (tester) async {
    await shoot(tester, '01_home_disconnected');
  });

  testWidgets('02 home connected with answer', (tester) async {
    await shoot(
      tester,
      '02_home_connected',
      before: () async {
        await harness.glasses.connect();
        harness.vision.show(
          const VisionState(
            status: VisionStatus.success,
            text: 'Перед вами пешеходный переход. Светофор зелёный, можно идти прямо.',
          ),
        );
      },
    );
  });

  testWidgets('03 assistant', (tester) async {
    await shoot(tester, '03_assistant', before: seed, tab: 'Помощник');
  });

  testWidgets('04 gallery', (tester) async {
    await shoot(tester, '04_gallery', before: seed, tab: 'Галерея');
  });

  testWidgets('05 settings', (tester) async {
    await shoot(tester, '05_settings', tab: 'Настройки');
  });
}
