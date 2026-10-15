import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seesay/core/accessibility/speech_messages.dart';
import 'package:seesay/features/home/presentation/accessible_action.dart';
import 'package:seesay/features/vision/presentation/vision_cubit.dart';

import '../../support/fake_vision_api.dart';
import '../../support/home_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<HomeHarness> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 2.75;
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

  testWidgets('home shows the glasses, three actions and no demo labels', (
    tester,
  ) async {
    await pump(tester);

    expect(find.text('Что вокруг'), findsOneWidget);
    expect(find.text('Текст'), findsOneWidget);
    expect(find.text('Повтор'), findsOneWidget);
    expect(find.text('Очки не подключены'), findsOneWidget);
    expect(find.text('Подключить очки'), findsOneWidget);
    expect(find.textContaining('имитац'), findsNothing);

    final photo = tester.getSize(find.byKey(const Key('action-photo')));
    expect(photo.height, greaterThanOrEqualTo(72));
  });

  testWidgets('home shows capture and error states from cubit state', (
    tester,
  ) async {
    final harness = await pump(tester);
    harness.vision.show(const VisionState(status: VisionStatus.capturing));
    await paint(tester);
    expect(find.text('Делаю снимок…'), findsOneWidget);

    harness.vision.show(
      const VisionState(
        status: VisionStatus.error,
        errorMessage: SpeechMessages.serverUnreachable,
      ),
    );
    await paint(tester);
    expect(find.text('Ошибка'), findsOneWidget);
    expect(find.text(SpeechMessages.serverUnreachable), findsOneWidget);
  });

  testWidgets('photo flow speaks the server response and repeats it', (
    tester,
  ) async {
    final harness = await pump(tester);
    await tester.runAsync(() async {
      tester
          .widget<AccessibleAction>(find.byKey(const Key('action-photo')))
          .onTap
          ?.call();
      await Future<void>.delayed(const Duration(milliseconds: 500));
    });
    await paint(tester);

    expect(find.text(fakeSceneResponse), findsOneWidget);
    expect(harness.engine.spoken, contains(fakeSceneResponse));

    await tester.runAsync(() async {
      tester
          .widget<AccessibleAction>(find.byKey(const Key('action-repeat')))
          .onTap
          ?.call();
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    expect(
      harness.engine.spoken.where((line) => line == fakeSceneResponse),
      hasLength(2),
    );
  });
}
