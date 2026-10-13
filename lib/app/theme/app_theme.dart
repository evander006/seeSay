import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

abstract final class AppColors {
  static const background = Color(0xFFF3F4F6);
  static const backgroundTop = Color(0xFFF3F4F6);
  static const card = Color(0xFFFFFFFF);
  static const ink = Color(0xFF1C1C1E);
  static const muted = Color(0xFF9AA1A9);
  static const accent = Color(0xFF2F7BFF);
  static const circle = Color(0xFFF2F3F5);
  static const danger = Color(0xFFD32F2F);
  static const ok = Color(0xFF22A45D);
  static const text = ink;
}

abstract final class AppTheme {
  static ThemeData get light {
    const text = TextStyle(color: AppColors.ink, fontSize: 18, height: 1.3);
    return ThemeData(
      brightness: Brightness.light,
      scaffoldBackgroundColor: AppColors.background,
      canvasColor: AppColors.background,
      colorScheme: const ColorScheme.light(
        surface: AppColors.card,
        primary: AppColors.accent,
        onPrimary: Colors.white,
        onSurface: AppColors.ink,
        error: AppColors.danger,
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: CupertinoPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.linux: CupertinoPageTransitionsBuilder(),
          TargetPlatform.windows: CupertinoPageTransitionsBuilder(),
          TargetPlatform.fuchsia: CupertinoPageTransitionsBuilder(),
        },
      ),
      splashColor: const Color(0x332F6BFF),
      highlightColor: const Color(0x142F6BFF),
      textTheme: const TextTheme(
        bodyLarge: text,
        bodyMedium: text,
        titleLarge: TextStyle(
          color: AppColors.ink,
          fontSize: 22,
          fontWeight: FontWeight.w700,
          height: 1.2,
        ),
        headlineMedium: TextStyle(
          color: AppColors.ink,
          fontSize: 28,
          fontWeight: FontWeight.w800,
          height: 1.15,
        ),
      ),
      sliderTheme: const SliderThemeData(
        activeTrackColor: AppColors.accent,
        thumbColor: AppColors.accent,
        inactiveTrackColor: Color(0xFFD5DDE6),
        overlayColor: Color(0x332F6BFF),
      ),
    );
  }
}
