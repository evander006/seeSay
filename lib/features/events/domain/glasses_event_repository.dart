import 'dart:async';

import 'package:seesay/core/events/recorded_event.dart';

abstract class GlassesEventRepository {
  bool get monitoring;

  bool get mockMode;

  Stream<RecordedEvent> get live;

  Future<void> startMonitoring();

  Future<void> stopMonitoring();

  Future<void> setMockMode(bool enabled);

  Future<RecordedEvent?> trigger(RecordedEventType type);

  Future<List<RecordedEvent>> pending();

  Future<void> acknowledge(String eventId);

  Future<List<RecordedEvent>> recent();
}

class MemoryGlassesEventRepository implements GlassesEventRepository {
  MemoryGlassesEventRepository({RecordedEventLog? log, this.idFactory})
    : log = log ?? RecordedEventLog();

  final RecordedEventLog log;
  final String Function()? idFactory;
  final _live = StreamController<RecordedEvent>.broadcast();
  var _monitoring = false;
  var _mockMode = true;
  var _sequence = 0;

  @override
  bool get monitoring => _monitoring;

  @override
  bool get mockMode => _mockMode;

  @override
  Stream<RecordedEvent> get live => _live.stream;

  @override
  Future<void> startMonitoring() async {
    _monitoring = true;
  }

  @override
  Future<void> stopMonitoring() async {
    _monitoring = false;
  }

  @override
  Future<void> setMockMode(bool enabled) async {
    _mockMode = enabled;
  }

  @override
  Future<RecordedEvent?> trigger(RecordedEventType type) async {
    if (!_monitoring || !_mockMode) return null;
    _sequence += 1;
    final event = RecordedEvent(
      eventId: idFactory?.call() ?? 'mock-$_sequence',
      type: type,
      timestamp: DateTime.now().toUtc(),
      source: RecordedEventSource.mock,
      status: type == RecordedEventType.deviceError
          ? RecordedEventStatus.failed
          : RecordedEventStatus.completed,
      text: _sampleText(type),
      batteryPercent: type == RecordedEventType.batteryChanged ? 80 : null,
      error: type == RecordedEventType.deviceError
          ? 'Нет ответа от очков.'
          : null,
    );
    if (!log.save(event)) return null;
    _live.add(event);
    return event;
  }

  @override
  Future<List<RecordedEvent>> pending() async => log.pending();

  @override
  Future<void> acknowledge(String eventId) async {
    log.acknowledge(eventId);
  }

  @override
  Future<List<RecordedEvent>> recent() async => log.items;

  String? _sampleText(RecordedEventType type) {
    return switch (type) {
      RecordedEventType.textRecognized => 'Выход к платформам направо',
      RecordedEventType.sceneAnalysisReady =>
        'Перед вами вход в аптеку. Дверь справа.',
      RecordedEventType.photoCaptured => null,
      RecordedEventType.deviceError => null,
      RecordedEventType.batteryChanged => null,
      RecordedEventType.glassesConnected => null,
      RecordedEventType.glassesDisconnected => null,
    };
  }
}
