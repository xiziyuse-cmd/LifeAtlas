import 'app_settings.dart';

abstract interface class AppSettingsRepository {
  Future<AppSettings> load();

  Future<void> saveThemePreference(AppThemePreference preference);

  Future<void> saveOutfitModuleEnabled(bool enabled);
}
