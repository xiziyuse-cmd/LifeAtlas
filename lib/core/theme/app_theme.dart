import 'package:flutter/material.dart';

abstract final class AppTheme {
  static const _seedColor = Color(0xFF496B59);

  static ThemeData get light {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(seedColor: _seedColor),
      scaffoldBackgroundColor: const Color(0xFFF7F8F5),
      appBarTheme: const AppBarTheme(centerTitle: false),
      navigationBarTheme: const NavigationBarThemeData(height: 72),
    );
  }

  static ThemeData get dark {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(
        seedColor: _seedColor,
        brightness: Brightness.dark,
      ),
      appBarTheme: const AppBarTheme(centerTitle: false),
      navigationBarTheme: const NavigationBarThemeData(height: 72),
    );
  }
}
