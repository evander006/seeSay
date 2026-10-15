import 'dart:async';
import 'dart:io';

import 'package:image/image.dart' as img;
import 'package:seesay/core/accessibility/haptic_service.dart';
import 'package:seesay/core/accessibility/tts_engine.dart';
import 'package:seesay/core/camera/camera_service.dart';
import 'package:seesay/core/logging/app_logger.dart';
import 'package:seesay/core/network/connectivity_service.dart';
import 'package:seesay/core/permissions/permission_service.dart';
import 'package:seesay/features/backend/backend_probe.dart';

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

/// Records what would be spoken.
class MockTtsEngine implements TtsEngine {
  final List<String> spoken = [];
  var stopCount = 0;
  double rate = 1;
  String language = 'ru-RU';
  var disposed = false;

  @override
  Future<void> speak(
    String text, {
    required double rate,
    required String language,
  }) async {
    spoken.add(text);
  }

  @override
  Future<void> stop() async {
    stopCount += 1;
  }

  @override
  Future<void> setSpeechRate(double rate) async {
    this.rate = rate;
  }

  @override
  Future<void> setLanguage(String language) async {
    this.language = language;
  }

  @override
  Future<void> dispose() async {
    disposed = true;
  }
}

/// A tiny dark JPEG instead of the phone camera.
class MockCameraService implements CameraService {
  MockCameraService({this.fail = false});

  bool fail;

  @override
  Future<File> capture() async {
    if (fail) throw StateError('camera');
    final image = img.Image(width: 16, height: 16);
    img.fill(image, color: img.ColorRgb8(20, 20, 20));
    final file = File(
      '${storageDir.path}${Platform.pathSeparator}seesay_test_${DateTime.now().microsecondsSinceEpoch}.jpg',
    );
    await file.writeAsBytes(img.encodeJpg(image, quality: 82), flush: true);
    return file;
  }
}

class FakeProbe extends BackendProbe {
  FakeProbe({this.ok = true});

  bool ok;
  final checked = <String>[];

  @override
  Future<ProbeResult> check(String baseUrl) async {
    checked.add(baseUrl);
    return ProbeResult(
      ok: ok,
      message: ok ? 'Сервер SeeSay на связи.' : 'Не удалось подключиться.',
    );
  }
}

/// Every permission granted, without the platform plugin.
class AllowAllPermissions extends PermissionService {
  AllowAllPermissions() : super(logger: AppLogger());

  @override
  Future<bool> ensureGlassesLink() async => true;

  @override
  Future<bool> ensureCamera() async => true;

  @override
  Future<bool> hasLocation() async => false;
}
