import 'dart:async';

import 'package:seesay/core/bluetooth/ble_packet_parser.dart';
import 'package:seesay/core/logging/app_logger.dart';
import 'package:seesay/core/platform/glasses_channel.dart';
import 'package:seesay/core/platform/glasses_protocol.dart';
import 'package:seesay/features/glasses/domain/glasses_repository.dart';

class GlassesRepositoryImpl implements GlassesRepository {
  GlassesRepositoryImpl({
    required this._channel,
    required this._parser,
    required this._logger,
  }) {
    _subscription = _channel.events().listen(
      _onRaw,
      onError: (Object error) {
        _logger.error('BLE disconnected', action: 'channel', error: error);
        _publish(
          const GlassesSnapshot(
            status: ConnectionStatus.error,
            message: 'Ошибка канала очков.',
          ),
        );
      },
    );
  }

  final GlassesChannel _channel;
  final BlePacketParser _parser;
  final AppLogger _logger;
  late final StreamSubscription<Map<String, dynamic>> _subscription;
  final _events = StreamController<GlassesEvent>.broadcast();
  GlassesSnapshot _current = const GlassesSnapshot();

  @override
  Stream<GlassesEvent> get events => _events.stream;

  @override
  GlassesSnapshot get current => _current;

  @override
  Future<bool> isAdapterEnabled() => _channel.isBluetoothEnabled();

  @override
  Future<void> connect({String? deviceAddress}) =>
      _channel.connect(deviceAddress);

  @override
  Future<void> disconnect() => _channel.disconnect();

  void _onRaw(Map<String, dynamic> raw) {
    switch (raw['event']) {
      case GlassesProtocol.bleConnectionChanged:
        final snapshot = GlassesSnapshot(
          status: connectionStatusFromWire(raw['state'] as String?),
          message: raw['message'] as String?,
          deviceAddress: raw['deviceAddress'] as String?,
          detail: raw['detail'] as String?,
        );
        if (snapshot.status == ConnectionStatus.connected) {
          _logger.info('BLE connected', action: 'connect');
        } else if (snapshot.status == ConnectionStatus.disconnected) {
          _logger.info('BLE disconnected', action: 'disconnect');
        }
        _publish(snapshot);
      case GlassesProtocol.blePacketReceived:
        final bytes = (raw['bytes'] as List?)?.whereType<int>().toList();
        if (bytes == null) return;
        final packet = _parser.parse(bytes);
        if (packet == null) return;
        _logger.info('photo trigger', action: packet.type.name);
        _events.add(BlePacketReceived(packet));
      case GlassesProtocol.mediaButtonEvent:
        _events.add(
          MediaButtonReceived(mediaButtonFromWire(raw['action'] as String?)),
        );
      case GlassesProtocol.glassesButton:
        _events.add(
          GlassesButtonPressed(
            raw['button'] as String? ?? '',
            raw['kind'] as String? ?? 'press',
          ),
        );
      case GlassesProtocol.voiceState:
        _events.add(
          VoiceStateChanged(
            raw['state'] as String? ?? '',
            raw['reason'] as String?,
          ),
        );
      case GlassesProtocol.voiceCaptured:
        _events.add(
          VoiceCaptured(
            path: raw['path'] as String,
            packets: (raw['packets'] as num?)?.toInt() ?? 0,
            durationMs: (raw['durationMs'] as num?)?.toInt() ?? 0,
            reason: raw['reason'] as String? ?? '',
          ),
        );
      case GlassesProtocol.glassesPhoto:
        _events.add(
          GlassesPhotoReceived(
            raw['path'] as String,
            raw['reason'] as String? ?? 'glasses',
            (raw['waitedMs'] as num?)?.toInt() ?? -1,
          ),
        );
      case GlassesProtocol.batteryChanged:
        final level = raw['level'];
        if (level is int) _events.add(BatteryChanged(level));
    }
  }

  void _publish(GlassesSnapshot snapshot) {
    _current = snapshot;
    _events.add(ConnectionChanged(snapshot));
  }

  Future<void> dispose() async {
    await _subscription.cancel();
    await _events.close();
  }
}
