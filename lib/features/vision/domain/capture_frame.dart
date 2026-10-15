import 'dart:io';

import 'package:seesay/core/camera/camera_service.dart';

class CaptureFrame {
  CaptureFrame({required this._camera});

  final CameraService _camera;

  /// JPEG up to ~1080p, already sized and compressed by the native side.
  Future<File> call() => _camera.capture();
}
