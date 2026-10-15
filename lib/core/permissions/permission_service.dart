import 'package:permission_handler/permission_handler.dart';
import 'package:seesay/core/logging/app_logger.dart';

class PermissionService {
  PermissionService({required this.logger});

  final AppLogger logger;

  Future<bool> ensureGlassesLink() async {
    final statuses = await [
      Permission.bluetooth,
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.notification,
      // Asked here, while the screen is open: photos are later taken in background.
      Permission.camera,
    ].request();
    final bluetoothOk =
        _ok(statuses[Permission.bluetoothScan]) &&
        _ok(statuses[Permission.bluetoothConnect]);
    final notificationsOk = _ok(statuses[Permission.notification]);
    if (!bluetoothOk || !notificationsOk) {
      logger.warning('permission denied', action: 'bluetooth');
      return false;
    }
    return true;
  }

  Future<bool> ensureNotifications() async {
    final status = await Permission.notification.request();
    if (!_ok(status)) {
      logger.warning('permission denied', action: 'notification');
      return false;
    }
    return true;
  }

  /// Checks the camera permission and asks for it only when it is missing.
  /// In background Android cannot show the dialog, so a missing permission is a failure.
  Future<bool> ensureCamera() async {
    try {
      if (await Permission.camera.isGranted) return true;
      final status = await Permission.camera.request();
      if (_ok(status)) return true;
    } on Object {
      logger.warning('permission request failed', action: 'camera');
    }
    logger.warning('permission denied', action: 'camera');
    return false;
  }

  /// Location is optional: it is used only if the user already allowed it.
  Future<bool> hasLocation() async {
    try {
      return await Permission.locationWhenInUse.isGranted;
    } on Object {
      return false;
    }
  }

  Future<void> openSettings() async {
    await openAppSettings();
  }

  bool _ok(PermissionStatus? status) {
    if (status == null) return false;
    return status.isGranted || status.isLimited;
  }
}
