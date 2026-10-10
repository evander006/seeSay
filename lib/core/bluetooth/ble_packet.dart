enum BleEventType {
  photoTrigger,
  captureStarted,
  doubleTap,
  videoInitialization,
  recording,
  idle,
  unknown,
}

class BlePacket {
  const BlePacket({required this.type, required this.bytes});

  final BleEventType type;
  final List<int> bytes;
}
