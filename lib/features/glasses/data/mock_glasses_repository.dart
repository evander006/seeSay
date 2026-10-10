import 'dart:async';

import 'package:seesay/core/bluetooth/ble_packet_parser.dart';
import 'package:seesay/core/platform/glasses_channel.dart';
import 'package:seesay/features/glasses/domain/glasses_repository.dart';

class MockGlassesRepository implements GlassesRepository {
  MockGlassesRepository({
    BlePacketParser? parser,
    this.adapterEnabled = true,
    this.connectDelay = const Duration(milliseconds: 300),
  }) : _parser = parser ?? BlePacketParser();

  final BlePacketParser _parser;
  bool adapterEnabled;
  Duration connectDelay;

  final _events = StreamController<GlassesEvent>.broadcast();
  GlassesSnapshot _current = const GlassesSnapshot();

  @override
  Stream<GlassesEvent> get events => _events.stream;

  @override
  GlassesSnapshot get current => _current;

  @override
  Future<bool> isAdapterEnabled() async => adapterEnabled;

  @override
  Future<void> connect({String? deviceAddress}) async {
    _publish(
      GlassesSnapshot(
        status: ConnectionStatus.connecting,
        deviceAddress: deviceAddress,
      ),
    );
    await Future<void>.delayed(connectDelay);
    _publish(
      const GlassesSnapshot(
        status: ConnectionStatus.connected,
        deviceAddress: 'MOCK:AIMB-S2',
        battery: 86,
      ),
    );
  }

  @override
  Future<void> disconnect() async {
    _publish(const GlassesSnapshot(status: ConnectionStatus.disconnected));
  }

  @override
  Future<void> simulatePhotoTrigger() async {
    final packet = _parser.parse(const [0xED, 0x40, 0x00, 0x12, 0x0F, 0x01]);
    if (packet != null) {
      _events.add(BlePacketReceived(packet));
    }
  }

  void emitPacket(List<int> bytes) {
    final packet = _parser.parse(bytes);
    if (packet != null) {
      _events.add(BlePacketReceived(packet));
    }
  }

  void _publish(GlassesSnapshot snapshot) {
    _current = snapshot;
    _events.add(ConnectionChanged(snapshot));
  }
}
