import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;

const glassesAsset = 'assets/imgs/glassesimg.png';

Uint8List knockoutBlackBackground(Uint8List bytes) {
  final decoded = img.decodeImage(bytes);
  if (decoded == null) return bytes;
  for (var y = 0; y < decoded.height; y++) {
    for (var x = 0; x < decoded.width; x++) {
      final pixel = decoded.getPixel(x, y);
      final red = pixel.r.toInt();
      final green = pixel.g.toInt();
      final blue = pixel.b.toInt();
      if (red < 16 && green < 16 && blue < 16) {
        decoded.setPixelRgba(x, y, red, green, blue, 0);
      }
    }
  }
  final trimmed = img.trim(decoded, mode: img.TrimMode.transparent);
  final result = trimmed.width < 8 || trimmed.height < 8 ? decoded : trimmed;
  return img.encodePng(result);
}

class GlassesArtwork extends StatefulWidget {
  const GlassesArtwork({required this.width, super.key});

  final double width;

  @override
  State<GlassesArtwork> createState() => _GlassesArtworkState();
}

class _GlassesArtworkState extends State<GlassesArtwork> {
  static Uint8List? _png;
  static Future<Uint8List>? _pending;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      _pending ??= _prepare();
      final bytes = await _pending!;
      _png = bytes;
    } on Object {
      _png ??= Uint8List(0);
    }
    if (mounted) setState(() {});
  }

  Future<Uint8List> _prepare() async {
    final data = await rootBundle.load(glassesAsset);
    final raw = data.buffer.asUint8List();
    try {
      return await compute(knockoutBlackBackground, raw);
    } on Object {
      return raw;
    }
  }

  @override
  Widget build(BuildContext context) {
    final bytes = _png;
    final height = widget.width * 0.42;
    if (bytes == null || bytes.isEmpty) {
      return SizedBox(width: widget.width, height: height);
    }
    return Image.memory(
      bytes,
      width: widget.width,
      height: height,
      fit: BoxFit.contain,
      gaplessPlayback: true,
      semanticLabel: 'Изображение очков SeeSay',
    );
  }
}

class GlassesRing extends StatelessWidget {
  const GlassesRing({required this.diameter, super.key});

  final double diameter;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.square(diameter),
      painter: const _RingPainter(),
    );
  }
}

class _RingPainter extends CustomPainter {
  const _RingPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFE3E6EB)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;
    canvas.drawCircle(size.center(Offset.zero), size.width / 2, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
