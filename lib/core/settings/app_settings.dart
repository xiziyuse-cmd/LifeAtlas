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

enum AppThemePalette {
  defaultTheme('默认', '森林绿 · 米白'),
  milkPudding('牛奶布丁', '柔黄 · 奶白'),
  mintSoda('薄荷苏打', '薄荷绿 · 白色'),
  berryShake('莓果奶昔', '浅粉 · 奶白'),
  seaSaltSoda('海盐汽水', '浅蓝 · 白色'),
  woodLatte('原木拿铁', '米色 · 浅棕');

  const AppThemePalette(this.label, this.description);
  final String label, description;
  static AppThemePalette fromStorage(String? value) => values.firstWhere(
    (theme) => theme.name == value,
    orElse: () => AppThemePalette.defaultTheme,
  );
}

class AppSettings {
  const AppSettings({
    this.themePreference = AppThemePreference.system,
    this.outfitModuleEnabled = false,
    this.kitchenModuleEnabled = false,
    this.profileGender = ProfileGender.unspecified,
    this.themePalette = AppThemePalette.defaultTheme,
  });

  final AppThemePreference themePreference;
  final bool outfitModuleEnabled;
  final bool kitchenModuleEnabled;
  final ProfileGender profileGender;
  final AppThemePalette themePalette;
}
