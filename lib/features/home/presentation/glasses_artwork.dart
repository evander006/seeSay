import 'package:flutter/material.dart';

const glassesAsset = 'assets/imgs/glassesimg.png';

/// Product shot of the glasses. The PNG already has a transparent background.
class GlassesArtwork extends StatelessWidget {
  const GlassesArtwork({required this.width, this.dimmed = false, super.key});

  final double width;

  /// Faded while the glasses are not connected.
  final bool dimmed;

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: dimmed ? 0.45 : 1,
      duration: const Duration(milliseconds: 300),
      child: Image.asset(
        glassesAsset,
        width: width,
        height: width * 0.36,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.medium,
        semanticLabel: 'Изображение очков SeeSay',
      ),
    );
  }
}
