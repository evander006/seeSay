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

  Future<bool> ensureCamera() async {
    final status = await Permission.camera.request();
    if (!_ok(status)) {
      logger.warning('permission denied', action: 'camera');
      return false;
    }
    return true;
  }

  Future<bool> ensureLocation() async {
    final status = await Permission.locationWhenInUse.request();
    if (!_ok(status)) {
      logger.warning('permission denied', action: 'location');
      return false;
    }
    return true;
  }

  Future<void> openSettings() async {
    await openAppSettings();
  }

  bool _ok(PermissionStatus? status) {
    if (status == null) return false;
    return status.isGranted || status.isLimited;
  }
}
