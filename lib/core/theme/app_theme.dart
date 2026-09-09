import 'package:flutter/material.dart';
import '../settings/app_settings.dart';

abstract final class AppTheme {
  static const _seeds = {
    AppThemePalette.defaultTheme: Color(0xFF496B59),
    AppThemePalette.milkPudding: Color(0xFFD3A936),
    AppThemePalette.mintSoda: Color(0xFF55A98A),
    AppThemePalette.berryShake: Color(0xFFC9798D),
    AppThemePalette.seaSaltSoda: Color(0xFF5B91C9),
    AppThemePalette.woodLatte: Color(0xFF987258),
  };
  static const _backgrounds = {
    AppThemePalette.defaultTheme: Color(0xFFF7F8F5),
    AppThemePalette.milkPudding: Color(0xFFFFFAE9),
    AppThemePalette.mintSoda: Color(0xFFF0FAF5),
    AppThemePalette.berryShake: Color(0xFFFFF3F5),
    AppThemePalette.seaSaltSoda: Color(0xFFF1F8FD),
    AppThemePalette.woodLatte: Color(0xFFFAF5EC),
  };

  static ThemeData light(AppThemePalette palette) =>
      _build(palette, Brightness.light);
  static ThemeData dark(AppThemePalette palette) =>
      _build(palette, Brightness.dark);
  static ThemeData _build(AppThemePalette palette, Brightness brightness) {
    final scheme = ColorScheme.fromSeed(
      seedColor: _seeds[palette]!,
      brightness: brightness,
    );
    final dark = brightness == Brightness.dark;
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
    );
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: dark
          ? const Color(0xFF111512)
          : _backgrounds[palette],
      cardTheme: CardThemeData(
        elevation: 1.5,
        margin: const EdgeInsets.symmetric(vertical: 6),
        shape: shape,
        color: dark
            ? scheme.surfaceContainer
            : Colors.white.withValues(alpha: .94),
      ),
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        backgroundColor: Colors.transparent,
        titleTextStyle: TextStyle(
          color: scheme.onSurface,
          fontSize: 22,
          fontWeight: FontWeight.w700,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 72,
        elevation: 4,
        backgroundColor: dark ? scheme.surfaceContainer : Colors.white,
        indicatorColor: scheme.secondaryContainer,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: dark
            ? scheme.surfaceContainerHighest.withValues(alpha: .45)
            : Colors.white.withValues(alpha: .82),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
      ),
      dialogTheme: DialogThemeData(
        shape: shape,
        backgroundColor: dark ? scheme.surfaceContainer : _backgrounds[palette],
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      dividerTheme: DividerThemeData(color: scheme.outlineVariant, space: 1),
      listTileTheme: ListTileThemeData(
        iconColor: scheme.primary,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      ),
    );
  }
}
