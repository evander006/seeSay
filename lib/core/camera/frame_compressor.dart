import 'dart:io';
import 'dart:math' as math;

import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:seesay/core/errors/app_exception.dart';

class FrameCompressor {
  FrameCompressor({this.directory, this.quality = 82});

  final Directory? directory;
  final int quality;

  static const maxWidth = 1920;
  static const maxHeight = 1080;

  Future<File> compress(File input) async {
    final bytes = await input.readAsBytes();
    final decoded = img.decodeImage(bytes);
    if (decoded == null) {
      throw CameraException('Не удалось прочитать изображение.');
    }

    var scaled = decoded;
    if (decoded.width > maxWidth || decoded.height > maxHeight) {
      final scale = math.min(
        maxWidth / decoded.width,
        maxHeight / decoded.height,
      );
      scaled = img.copyResize(
        decoded,
        width: math.max(1, (decoded.width * scale).round()),
        height: math.max(1, (decoded.height * scale).round()),
        interpolation: img.Interpolation.linear,
      );
    }

    final encoded = img.encodeJpg(scaled, quality: quality);
    final dir = directory ?? await getTemporaryDirectory();
    final output = File(
      '${dir.path}${Platform.pathSeparator}seesay_${DateTime.now().microsecondsSinceEpoch}.jpg',
    );
    await output.writeAsBytes(encoded, flush: true);
    if (output.path != input.path && await input.exists()) {
      await input.delete();
    }
    return output;
  }
}
