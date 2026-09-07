import 'package:flutter/material.dart';

enum AppThemePreference {
  system,
  light,
  dark;

  ThemeMode get themeMode {
    return switch (this) {
      AppThemePreference.system => ThemeMode.system,
      AppThemePreference.light => ThemeMode.light,
      AppThemePreference.dark => ThemeMode.dark,
    };
  }

  static AppThemePreference fromStorage(String? value) {
    return AppThemePreference.values.firstWhere(
      (preference) => preference.name == value,
      orElse: () => AppThemePreference.system,
    );
  }
}

enum ProfileGender {
  unspecified('未设置'),
  male('男性'),
  female('女性');

  const ProfileGender(this.label);

  final String label;

  static ProfileGender fromStorage(String? value) {
    return ProfileGender.values.firstWhere(
      (gender) => gender.name == value,
      orElse: () => ProfileGender.unspecified,
    );
  }
}

class AppSettings {
  const AppSettings({
    this.themePreference = AppThemePreference.system,
    this.outfitModuleEnabled = false,
    this.kitchenModuleEnabled = false,
    this.profileGender = ProfileGender.unspecified,
  });

  final AppThemePreference themePreference;
  final bool outfitModuleEnabled;
  final bool kitchenModuleEnabled;
  final ProfileGender profileGender;
}
