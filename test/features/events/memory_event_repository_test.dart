import 'package:flutter_test/flutter_test.dart';
import 'package:seesay/core/events/recorded_event.dart';
import 'package:seesay/features/events/domain/glasses_event_repository.dart';

void main() {
  test('trigger is idle until monitoring and mock mode are on', () async {
    final repository = MemoryGlassesEventRepository();
    expect(
      await repository.trigger(RecordedEventType.textRecognized),
      isNull,
    );

    await repository.startMonitoring();
    await repository.setMockMode(false);
    expect(await repository.trigger(RecordedEventType.textRecognized), isNull);

    await repository.setMockMode(true);
    final event = await repository.trigger(RecordedEventType.textRecognized);
    expect(event, isNotNull);
    expect(event!.source, RecordedEventSource.mock);
    expect(event.text, 'Выход к платформам направо');
    expect(event.eventId, 'mock-1');

    await repository.acknowledge(event.eventId);
    expect(await repository.pending(), isEmpty);
    expect(await repository.recent(), [event.copyWith(acknowledged: true)]);
  });

  test('duplicate event ids are not broadcast twice', () async {
    var calls = 0;
    final repository = MemoryGlassesEventRepository(idFactory: () => 'same');
    final seen = <RecordedEvent>[];
    final subscription = repository.live.listen(seen.add);
    await repository.startMonitoring();
    expect(await repository.trigger(RecordedEventType.batteryChanged), isNotNull);
    expect(await repository.trigger(RecordedEventType.batteryChanged), isNull);
    calls = seen.length;
    await subscription.cancel();
    expect(calls, 1);
    expect(seen.single.source, RecordedEventSource.mock);
  });
}
