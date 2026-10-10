import 'package:flutter_test/flutter_test.dart';
import 'package:seesay/core/events/recorded_event.dart';

void main() {
  RecordedEvent sample({String id = 'mock-event-001', bool acknowledged = false}) {
    return RecordedEvent(
      eventId: id,
      type: RecordedEventType.textRecognized,
      timestamp: DateTime.utc(2026, 10, 9, 12),
      source: RecordedEventSource.mock,
      status: RecordedEventStatus.completed,
      text: 'Выход к платформам направо',
      acknowledged: acknowledged,
    );
  }

  test('serializes nullable fields and source', () {
    final event = sample();
    final json = event.toJson();
    final restored = RecordedEvent.fromJson(json);

    expect(restored, event);
    expect(restored.source, RecordedEventSource.mock);
    expect(restored.simulated, isTrue);
    expect(restored.batteryPercent, isNull);
    expect(restored.error, isNull);
    expect(json['type'], 'TEXT_RECOGNIZED');
  });

  test('log deduplicates ids, acknowledges, and keeps the newest limit', () {
    final log = RecordedEventLog(limit: 2);
    expect(log.save(sample(id: 'a')), isTrue);
    expect(log.save(sample(id: 'a')), isFalse);
    expect(log.save(sample(id: 'b')), isTrue);
    expect(log.save(sample(id: 'c')), isTrue);

    expect(log.items.map((item) => item.eventId), ['c', 'b']);
    expect(log.pending(), hasLength(2));
    expect(log.acknowledge('b'), isTrue);
    expect(log.pending().map((item) => item.eventId), ['c']);
    expect(log.acknowledge('missing'), isFalse);
  });
}
