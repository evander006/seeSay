import 'package:flutter_test/flutter_test.dart';
import 'package:seesay/core/accessibility/semantics_builder.dart';
import 'package:seesay/core/accessibility/touch_exploration_service.dart';

void main() {
  test('does not repeat the same zone inside the debounce window', () {
    final service = TouchExplorationService(
      debounce: const Duration(milliseconds: 1200),
    );
    final first = DateTime(2026, 1, 1, 12);
    expect(service.shouldSpeak('photo', first), isTrue);
    expect(
      service.shouldSpeak(
        'photo',
        first.add(const Duration(milliseconds: 500)),
      ),
      isFalse,
    );
    expect(
      service.shouldSpeak('ocr', first.add(const Duration(milliseconds: 600))),
      isTrue,
    );
  });

  test('a finished hold suppresses the following tap', () {
    final service = TouchExplorationService();
    final zone = ExplorationZone(
      id: 'photo',
      label: 'Сделать фото',
      hint: 'Двойное нажатие для активации',
      bounds: null,
    );
    String? spoken;
    service.onPointerDown(
      pointerId: 1,
      zone: zone,
      enabled: true,
      onExplore: (value) => spoken = value.spoken,
    );
    service.exploredThisGesture = true;
    service.suppressTapForId = 'photo';
    expect(service.consumeTap('photo'), isTrue);
    service.dispose();
    expect(spoken, isNull);
    expect(
      semanticsAnnouncement(
        label: 'Сделать фото',
        hint: 'Двойное нажатие для активации',
      ),
      'Сделать фото. Двойное нажатие для активации.',
    );
  });

  test('hold announces the zone after the delay', () {
    final service = TouchExplorationService(
      exploreDelay: const Duration(milliseconds: 700),
    );
    final zone = ExplorationZone(
      id: 'photo',
      label: 'Сделать фото',
      hint: 'Двойное нажатие для активации',
      bounds: null,
    );
    String? spoken;
    service.onPointerDown(
      pointerId: 1,
      zone: zone,
      enabled: true,
      onExplore: (value) => spoken = value.id,
    );
    expect(spoken, isNull);
    service.dispose();
  });
}
