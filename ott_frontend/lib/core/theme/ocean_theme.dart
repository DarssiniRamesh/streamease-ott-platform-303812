import 'package:flutter/material.dart';

class OceanTheme {
  static const Color _primary = Color(0xFF2563EB); // Ocean Professional primary
  static const Color _secondary = Color(0xFFF59E0B); // Accent
  static const Color _error = Color(0xFFEF4444);
  static const Color _surface = Color(0xFFFFFFFF);
  static const Color _background = Color(0xFFF9FAFB);
  static const Color _text = Color(0xFF111827);

  static final ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: _primary,
      primary: _primary,
      secondary: _secondary,
      error: _error,
      surface: _surface,
      brightness: Brightness.light,
    ),
    scaffoldBackgroundColor: _background,
    textTheme: Typography.material2021().black.apply(
          bodyColor: _text,
          displayColor: _text,
        ),
    appBarTheme: AppBarTheme(
      backgroundColor: _background,
      surfaceTintColor: _background,
      elevation: 0,
      titleTextStyle: Typography.material2021().black.titleLarge?.copyWith(
            color: _text,
            fontWeight: FontWeight.w700,
          ),
      iconTheme: const IconThemeData(color: _text),
    ),
    cardTheme: CardTheme(
      color: _surface,
      surfaceTintColor: _surface,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    listTileTheme: ListTileThemeData(
      iconColor: _text,
      textColor: _text,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: _surface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: _primary.withAlpha(30)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: _primary.withAlpha(20)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: _primary.withAlpha(160)),
      ),
    ),
  );
}
