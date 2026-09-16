import 'package:flutter/material.dart';

abstract final class AppTheme {
  static const background = Color(0xFF070B0D);
  static const surface = Color(0xFF101719);
  static const primary = Color(0xFF2DD4BF);
  static const finance = Color(0xFFF2B84B);
  static const error = Color(0xFFFB7185);

  static ThemeData dark() => _theme(
        brightness: Brightness.dark,
        background: background,
        surface: surface,
        onSurface: const Color(0xFFF2F7F6),
      );

  static ThemeData light() => _theme(
        brightness: Brightness.light,
        background: const Color(0xFFF3F7F6),
        surface: Colors.white,
        onSurface: const Color(0xFF10201E),
      );

  static ThemeData _theme({
    required Brightness brightness,
    required Color background,
    required Color surface,
    required Color onSurface,
  }) {
    final scheme = ColorScheme.fromSeed(
      seedColor: primary,
      brightness: brightness,
      surface: surface,
      error: error,
    ).copyWith(primary: primary, surface: surface, onSurface: onSurface);
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: background,
      fontFamily: 'Manrope',
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 72,
        backgroundColor: surface,
        indicatorColor: primary.withValues(alpha: .18),
      ),
      chipTheme: ChipThemeData(
        side: BorderSide(color: scheme.outlineVariant),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(48, 52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
    );
  }
}
