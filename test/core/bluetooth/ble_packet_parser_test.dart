import 'package:flutter_test/flutter_test.dart';
import 'package:seesay/core/bluetooth/ble_packet.dart';
import 'package:seesay/core/bluetooth/ble_packet_parser.dart';

void main() {
  final parser = BlePacketParser();

  test('rejects a packet without the magic header', () {
    expect(parser.parse([0x00, 0x40, 0x12, 0x0F, 0x01]), isNull);
  });

  test('recognizes a photo trigger after the header', () {
    final packet = parser.parse([0xED, 0x40, 0x00, 0x12, 0x0F, 0x01]);
    expect(packet?.type, BleEventType.photoTrigger);
  });

  test('recognizes capture started', () {
    expect(
      parser.parse([0xED, 0x40, 0x12, 0x0D, 0x01, 0x01])?.type,
      BleEventType.captureStarted,
    );
  });

  test('recognizes a double tap with leading bytes', () {
    expect(
      parser.parse([0xED, 0x40, 0xAA, 0xBB, 0x12, 0x0D, 0x04, 0x01])?.type,
      BleEventType.doubleTap,
    );
  });

  test('recognizes video, recording and idle packets', () {
    expect(
      parser.parse([0xED, 0x40, 0x12, 0x0D, 0x02, 0x02])?.type,
      BleEventType.videoInitialization,
    );
    expect(
      parser.parse([0xED, 0x40, 0x12, 0x0D, 0x02, 0x01])?.type,
      BleEventType.recording,
    );
    expect(
      parser.parse([0xED, 0x40, 0x12, 0x0D, 0x00, 0x00])?.type,
      BleEventType.idle,
    );
  });

  test('keeps an unknown packet when the header is valid', () {
    expect(parser.parse([0xED, 0x40, 0x01])?.type, BleEventType.unknown);
  });
}
