import 'dart:io';

import 'package:camera/camera.dart' hide CameraException;
import 'package:image/image.dart' as img;
import 'package:seesay/core/errors/app_exception.dart';
import 'package:seesay/core/permissions/permission_service.dart';

abstract class CameraService {
  Future<File> capture();

  Future<void> dispose();
}

class PhoneCameraService implements CameraService {
  PhoneCameraService({required this.permissions});

  final PermissionService permissions;
  CameraController? _controller;

  @override
  Future<File> capture() async {
    final allowed = await permissions.ensureCamera();
    if (!allowed) {
      throw PermissionException('Нет необходимого разрешения.');
    }

    await _controller?.dispose();
    _controller = null;

    final cameras = await availableCameras();
    if (cameras.isEmpty) {
      throw CameraException('Камера недоступна.');
    }

    final controller = CameraController(
      cameras.first,
      ResolutionPreset.veryHigh,
      enableAudio: false,
    );
    _controller = controller;
    try {
      await controller.initialize();
      final shot = await controller.takePicture();
      return File(shot.path);
    } finally {
      await controller.dispose();
      if (identical(_controller, controller)) _controller = null;
    }
  }

  @override
  Future<void> dispose() async {
    await _controller?.dispose();
    _controller = null;
  }
}

class MockCameraService implements CameraService {
  MockCameraService({this._directory});

  final Directory? _directory;

  @override
  Future<File> capture() async {
    final image = img.Image(width: 16, height: 16);
    img.fill(image, color: img.ColorRgb8(20, 20, 20));
    final bytes = img.encodeJpg(image, quality: 82);
    final dir = _directory ?? Directory.systemTemp;
    final file = File(
      '${dir.path}${Platform.pathSeparator}seesay_mock_${DateTime.now().microsecondsSinceEpoch}.jpg',
    );
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  @override
  Future<void> dispose() async {}
}
