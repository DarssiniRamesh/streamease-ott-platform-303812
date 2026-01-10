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
      centerTitle: false,
      titleTextStyle: Typography.material2021().black.titleLarge?.copyWith(
            color: _text,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.2,
          ),
      iconTheme: const IconThemeData(color: _text),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: _surface,
      indicatorColor: _primary.withAlpha(18),
      labelTextStyle: WidgetStatePropertyAll(
        Typography.material2021().black.labelMedium?.copyWith(fontWeight: FontWeight.w700),
      ),
    ),
    cardTheme: CardTheme(
      color: _surface,
      surfaceTintColor: _surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    chipTheme: ChipThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      side: BorderSide(color: _primary.withAlpha(18)),
      backgroundColor: _primary.withAlpha(10),
      labelStyle: Typography.material2021().black.labelLarge?.copyWith(color: _text),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: ButtonStyle(
        shape: WidgetStatePropertyAll(RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
        padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 16, vertical: 14)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: ButtonStyle(
        shape: WidgetStatePropertyAll(RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
        side: WidgetStatePropertyAll(BorderSide(color: _primary.withAlpha(40))),
        padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 16, vertical: 14)),
      ),
    ),
    listTileTheme: ListTileThemeData(
      iconColor: _text,
      textColor: _text,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    dividerTheme: DividerThemeData(color: _primary.withAlpha(12)),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: _surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
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
