import 'dart:async';
import 'dart:io';

import 'package:seesay/core/accessibility/haptic_service.dart';
import 'package:seesay/core/network/connectivity_service.dart';

final storageDir = Directory.systemTemp;

class FakeConnectivity implements ConnectivityService {
  FakeConnectivity({required this.online});

  bool online;
  final _updates = StreamController<bool>.broadcast();

  @override
  Future<bool> get isOnline async => online;

  @override
  Stream<bool> get onStatusChanged => _updates.stream;

  void emit(bool value) {
    online = value;
    _updates.add(value);
  }
}

class QuietFeedback implements SystemFeedback {
  @override
  Future<void> beep(HapticKind kind) async {}

  @override
  Future<void> haptic(HapticKind kind) async {}
}
