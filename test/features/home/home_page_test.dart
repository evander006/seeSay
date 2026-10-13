import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seesay/core/accessibility/speech_messages.dart';
import 'package:seesay/core/config/demo_content.dart';
import 'package:seesay/features/home/presentation/accessible_action.dart';
import 'package:seesay/features/vision/presentation/vision_cubit.dart';

import '../../support/home_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<HomeHarness> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final harness = HomeHarness();
    addTearDown(harness.dispose);
    await tester.pumpWidget(harness.app());
    await tester.pump();
    return harness;
  }

  Future<void> paint(WidgetTester tester) async {
    await tester.pump();
    await tester.pump();
  }

  testWidgets('home exposes labels, hints and large actions', (tester) async {
    await pump(tester);

    expect(find.text('Что вокруг'), findsOneWidget);
    expect(find.text('Текст'), findsOneWidget);
    expect(find.text('Повтор'), findsOneWidget);
    expect(find.text('Значения имитации не приходят с очков.'), findsOneWidget);

    final photo = tester.getSize(find.byKey(const Key('action-photo')));
    expect(photo.height, greaterThanOrEqualTo(72));
    expect(photo.width, greaterThanOrEqualTo(200));
    final title = tester.widget<Text>(find.text('Что вокруг'));
    expect(title.style!.fontSize, greaterThanOrEqualTo(18));
    expect(find.text('Очки не подключены'), findsOneWidget);
    expect(find.text('Готово'), findsOneWidget);
  });

  testWidgets('home shows capture and error states from cubit state', (
    tester,
  ) async {
    final harness = await pump(tester);
    harness.vision.show(const VisionState(status: VisionStatus.capturing));
    await paint(tester);
    expect(find.text('Захват изображения...'), findsOneWidget);

    harness.vision.show(
      const VisionState(
        status: VisionStatus.error,
        errorMessage: SpeechMessages.networkUnavailable,
      ),
    );
    await paint(tester);
    expect(find.text('Ошибка'), findsOneWidget);
    expect(find.text(SpeechMessages.networkUnavailable), findsOneWidget);
  });

  testWidgets('photo flow speaks the mocked response', (tester) async {
    final harness = await pump(tester);
    await tester.runAsync(() async {
      tester
          .widget<AccessibleAction>(find.byKey(const Key('action-photo')))
          .onTap
          ?.call();
      await Future<void>.delayed(const Duration(milliseconds: 500));
    });
    await paint(tester);

    expect(find.text(DemoContent.sceneResponse), findsOneWidget);
    expect(harness.engine.spoken, contains(DemoContent.sceneResponse));

    await tester.tap(find.byKey(const Key('action-repeat')));
    await paint(tester);
    expect(
      harness.engine.spoken.where((line) => line == DemoContent.sceneResponse),
      hasLength(2),
    );
  });
}
