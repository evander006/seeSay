import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:seesay/core/accessibility/accessibility_audio_queue.dart';

void main() {
  test('speaks queued messages in order', () async {
    final spoken = <String>[];
    final queue = AccessibilityAudioQueue(
      speak: (text) async => spoken.add(text),
      stop: () async {},
    );

    await queue.enqueue(
      const SpeechRequest(
        text: 'первое',
        priority: SpeechPriority.normal,
        interrupt: false,
      ),
    );
    await queue.enqueue(
      const SpeechRequest(
        text: 'второе',
        priority: SpeechPriority.normal,
        interrupt: false,
      ),
    );

    expect(spoken, ['первое', 'второе']);
  });

  test('a high-priority message stops current speech', () async {
    final spoken = <String>[];
    final started = Completer<void>();
    final release = Completer<void>();
    final queue = AccessibilityAudioQueue(
      speak: (text) async {
        spoken.add(text);
        if (text == 'долгое') {
          started.complete();
          await release.future;
        }
      },
      stop: () async {
        if (!release.isCompleted) release.complete();
      },
    );

    final first = queue.enqueue(
      const SpeechRequest(
        text: 'долгое',
        priority: SpeechPriority.normal,
        interrupt: false,
      ),
    );
    await started.future;
    await queue.enqueue(
      const SpeechRequest(
        text: 'ошибка',
        priority: SpeechPriority.high,
        interrupt: true,
      ),
    );
    await first;

    expect(spoken, ['долгое', 'ошибка']);
  });
}
