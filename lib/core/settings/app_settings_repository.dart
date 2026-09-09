import 'app_settings.dart';

abstract interface class AppSettingsRepository {
  Future<AppSettings> load();

  Future<void> saveThemePreference(AppThemePreference preference);
  Future<void> saveThemePalette(AppThemePalette palette);

  Future<void> saveOutfitModuleEnabled(bool enabled);
  Future<void> saveKitchenModuleEnabled(bool enabled);

  Future<void> saveProfileGender(ProfileGender gender);
}
