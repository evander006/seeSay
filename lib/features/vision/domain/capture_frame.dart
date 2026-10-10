import 'dart:io';

import 'package:seesay/core/camera/camera_service.dart';
import 'package:seesay/core/camera/frame_compressor.dart';

class CaptureFrame {
  CaptureFrame({required this._camera, required this._compressor});

  final CameraService _camera;
  final FrameCompressor _compressor;

  Future<File> call() async {
    final raw = await _camera.capture();
    return _compressor.compress(raw);
  }
}
