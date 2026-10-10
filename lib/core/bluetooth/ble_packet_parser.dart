import 'package:seesay/core/bluetooth/ble_packet.dart';

class BlePacketParser {
  static const int magic0 = 0xED;
  static const int magic1 = 0x40;

  static const List<int> photoTrigger = [0x12, 0x0F, 0x01];
  static const List<int> captureStarted = [0x12, 0x0D, 0x01, 0x01];
  static const List<int> doubleTap = [0x12, 0x0D, 0x04, 0x01];
  static const List<int> videoInitialization = [0x12, 0x0D, 0x02, 0x02];
  static const List<int> recording = [0x12, 0x0D, 0x02, 0x01];
  static const List<int> idle = [0x12, 0x0D, 0x00, 0x00];

  static const _patterns = <(List<int>, BleEventType)>[
    (captureStarted, BleEventType.captureStarted),
    (doubleTap, BleEventType.doubleTap),
    (videoInitialization, BleEventType.videoInitialization),
    (recording, BleEventType.recording),
    (idle, BleEventType.idle),
    (photoTrigger, BleEventType.photoTrigger),
  ];

  BlePacket? parse(List<int> bytes) {
    if (bytes.length < 2 || bytes[0] != magic0 || bytes[1] != magic1) {
      return null;
    }

    var bestIndex = -1;
    var bestType = BleEventType.unknown;
    for (final (pattern, type) in _patterns) {
      final index = _indexOf(bytes, pattern, start: 2);
      if (index >= 0 && (bestIndex == -1 || index < bestIndex)) {
        bestIndex = index;
        bestType = type;
      }
    }

    return BlePacket(type: bestType, bytes: List<int>.unmodifiable(bytes));
  }

  int _indexOf(List<int> data, List<int> pattern, {required int start}) {
    if (pattern.isEmpty || data.length < start + pattern.length) return -1;
    for (var i = start; i <= data.length - pattern.length; i++) {
      var matches = true;
      for (var j = 0; j < pattern.length; j++) {
        if (data[i + j] != pattern[j]) {
          matches = false;
          break;
        }
      }
      if (matches) return i;
    }
    return -1;
  }
}
