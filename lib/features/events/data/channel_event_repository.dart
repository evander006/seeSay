import 'dart:async';

import 'package:seesay/core/events/recorded_event.dart';
import 'package:seesay/core/platform/glasses_channel.dart';
import 'package:seesay/core/platform/glasses_protocol.dart';
import 'package:seesay/features/events/domain/glasses_event_repository.dart';

class ChannelGlassesEventRepository implements GlassesEventRepository {
  ChannelGlassesEventRepository(this._channel) {
    _subscription = _channel.events().listen(_onRaw, onError: (_) {});
  }

  final GlassesChannel _channel;
  final RecordedEventLog _log = RecordedEventLog();
  final _live = StreamController<RecordedEvent>.broadcast();
  late final StreamSubscription<Map<String, dynamic>> _subscription;
  var _monitoring = false;
  var _mockMode = true;

  @override
  bool get monitoring => _monitoring;

  @override
  bool get mockMode => _mockMode;

  @override
  Stream<RecordedEvent> get live => _live.stream;

  @override
  Future<void> startMonitoring() async {
    await _channel.startBackgroundMonitoring();
    _monitoring = true;
  }

  @override
  Future<void> stopMonitoring() async {
    await _channel.stopBackgroundMonitoring();
    _monitoring = false;
  }

  @override
  Future<void> setMockMode(bool enabled) async {
    if (enabled) {
      await _channel.enableMockMode();
    } else {
      await _channel.disableMockMode();
    }
    _mockMode = enabled;
  }

  @override
  Future<RecordedEvent?> trigger(RecordedEventType type) async {
    await _channel.triggerMockEvent(type.wire);
    final items = await recent();
    for (final event in items) {
      if (event.type == type) return event;
    }
    return null;
  }

  @override
  Future<List<RecordedEvent>> pending() async {
    final remote = await _channel.pendingGlassesEvents();
    return _merge(remote).where((event) => !event.acknowledged).toList();
  }

  @override
  Future<void> acknowledge(String eventId) async {
    _log.acknowledge(eventId);
    await _channel.acknowledgeGlassesEvent(eventId);
  }

  @override
  Future<List<RecordedEvent>> recent() async {
    final remote = await _channel.recentGlassesEvents();
    if (remote.isEmpty) return _log.items;
    return _merge(remote);
  }

  List<RecordedEvent> _merge(List<Map<String, dynamic>> raw) {
    for (final item in raw) {
      final event = RecordedEvent.fromJson(item);
      _log.save(event);
    }
    return _log.items;
  }

  void _onRaw(Map<String, dynamic> raw) {
    if (raw['event'] != GlassesProtocol.glassesEvent) return;
    final event = RecordedEvent.fromJson(raw);
    if (_log.save(event)) _live.add(event);
  }

  Future<void> dispose() async {
    await _subscription.cancel();
    await _live.close();
  }
}
