import 'dart:io';

import 'package:seesay/core/errors/app_exception.dart';
import 'package:seesay/core/permissions/permission_service.dart';
import 'package:seesay/core/platform/glasses_channel.dart';

abstract class CameraService {
  Future<File> capture();
}

/// Phone's back camera through Android Camera2. Works with the app in the background
/// because the glasses service runs with the camera foreground type.
class NativeCameraService implements CameraService {
  NativeCameraService({required this._channel, required this._permissions});

  final GlassesChannel _channel;
  final PermissionService _permissions;

  @override
  Future<File> capture() async {
    if (!await _permissions.ensureCamera()) {
      throw PermissionException('Нет разрешения на камеру.');
    }
    return File(await _channel.capturePhoto());
  }
}
