import 'package:equatable/equatable.dart';

enum RecordedEventType {
  glassesConnected,
  batteryChanged,
  photoCaptured,
  textRecognized,
  sceneAnalysisReady,
  glassesDisconnected,
  deviceError,
}

enum RecordedEventSource { mock, ble, backend }

enum RecordedEventStatus { completed, failed }

class RecordedEvent extends Equatable {
  const RecordedEvent({
    required this.eventId,
    required this.type,
    required this.timestamp,
    required this.source,
    required this.status,
    this.text,
    this.batteryPercent,
    this.error,
    this.acknowledged = false,
  });

  final String eventId;
  final RecordedEventType type;
  final DateTime timestamp;
  final RecordedEventSource source;
  final RecordedEventStatus status;
  final String? text;
  final int? batteryPercent;
  final String? error;
  final bool acknowledged;

  RecordedEvent copyWith({bool? acknowledged}) {
    return RecordedEvent(
      eventId: eventId,
      type: type,
      timestamp: timestamp,
      source: source,
      status: status,
      text: text,
      batteryPercent: batteryPercent,
      error: error,
      acknowledged: acknowledged ?? this.acknowledged,
    );
  }

  Map<String, Object?> toJson() {
    return {
      'eventId': eventId,
      'type': type.wire,
      'timestamp': timestamp.toUtc().toIso8601String(),
      'source': source.name,
      'status': status.name,
      'text': text,
      'batteryPercent': batteryPercent,
      'error': error,
      'acknowledged': acknowledged,
    };
  }

  factory RecordedEvent.fromJson(Map<String, dynamic> json) {
    return RecordedEvent(
      eventId: json['eventId'] as String,
      type: RecordedEventTypes.parse(json['type'] as String?),
      timestamp: DateTime.parse(json['timestamp'] as String).toUtc(),
      source: RecordedEventSource.values.byName(
        (json['source'] as String?) ?? 'mock',
      ),
      status: (json['status'] as String?) == 'failed'
          ? RecordedEventStatus.failed
          : RecordedEventStatus.completed,
      text: json['text'] as String?,
      batteryPercent: json['batteryPercent'] as int?,
      error: json['error'] as String?,
      acknowledged: json['acknowledged'] == true,
    );
  }

  bool get simulated => source == RecordedEventSource.mock;

  @override
  List<Object?> get props => [
    eventId,
    type,
    timestamp,
    source,
    status,
    text,
    batteryPercent,
    error,
    acknowledged,
  ];
}

extension RecordedEventTypeWire on RecordedEventType {
  String get wire => switch (this) {
    RecordedEventType.glassesConnected => 'GLASSES_CONNECTED',
    RecordedEventType.batteryChanged => 'BATTERY_CHANGED',
    RecordedEventType.photoCaptured => 'PHOTO_CAPTURED',
    RecordedEventType.textRecognized => 'TEXT_RECOGNIZED',
    RecordedEventType.sceneAnalysisReady => 'SCENE_ANALYSIS_READY',
    RecordedEventType.glassesDisconnected => 'GLASSES_DISCONNECTED',
    RecordedEventType.deviceError => 'DEVICE_ERROR',
  };

  String get label => switch (this) {
    RecordedEventType.glassesConnected => 'Очки подключены',
    RecordedEventType.batteryChanged => 'Заряд',
    RecordedEventType.photoCaptured => 'Снимок',
    RecordedEventType.textRecognized => 'Текст',
    RecordedEventType.sceneAnalysisReady => 'Сцена',
    RecordedEventType.glassesDisconnected => 'Очки отключены',
    RecordedEventType.deviceError => 'Ошибка устройства',
  };
}

abstract final class RecordedEventTypes {
  static RecordedEventType parse(String? raw) {
    return switch (raw) {
      'GLASSES_CONNECTED' => RecordedEventType.glassesConnected,
      'BATTERY_CHANGED' => RecordedEventType.batteryChanged,
      'PHOTO_CAPTURED' => RecordedEventType.photoCaptured,
      'TEXT_RECOGNIZED' => RecordedEventType.textRecognized,
      'SCENE_ANALYSIS_READY' => RecordedEventType.sceneAnalysisReady,
      'GLASSES_DISCONNECTED' => RecordedEventType.glassesDisconnected,
      'DEVICE_ERROR' => RecordedEventType.deviceError,
      _ => RecordedEventType.deviceError,
    };
  }
}

class RecordedEventLog {
  RecordedEventLog({this.limit = 100});

  final int limit;
  final List<RecordedEvent> _items = [];

  List<RecordedEvent> get items => List.unmodifiable(_items);

  bool save(RecordedEvent event) {
    if (_items.any((item) => item.eventId == event.eventId)) return false;
    _items.insert(0, event);
    if (_items.length > limit) {
      _items.removeRange(limit, _items.length);
    }
    return true;
  }

  List<RecordedEvent> pending() {
    return _items.where((item) => !item.acknowledged).toList(growable: false);
  }

  bool acknowledge(String eventId) {
    final index = _items.indexWhere((item) => item.eventId == eventId);
    if (index < 0) return false;
    _items[index] = _items[index].copyWith(acknowledged: true);
    return true;
  }

  void replaceAll(List<RecordedEvent> events) {
    _items
      ..clear()
      ..addAll(events);
  }
}
