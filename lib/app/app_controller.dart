import 'package:flutter/foundation.dart';

import '../core/settings/app_settings.dart';
import '../core/settings/app_settings_repository.dart';

class AppController extends ChangeNotifier {
  AppController(this._settingsRepository);

  final AppSettingsRepository _settingsRepository;

  AppThemePreference _themePreference = AppThemePreference.system;
  bool _outfitModuleEnabled = false;
  bool _initialized = false;

  AppThemePreference get themePreference => _themePreference;
  bool get outfitModuleEnabled => _outfitModuleEnabled;
  bool get initialized => _initialized;

  Future<void> initialize() async {
    final settings = await _settingsRepository.load();
    _themePreference = settings.themePreference;
    _outfitModuleEnabled = settings.outfitModuleEnabled;
    _initialized = true;
    notifyListeners();
  }

  Future<void> setThemePreference(AppThemePreference preference) async {
    if (_themePreference == preference) {
      return;
    }

    await _settingsRepository.saveThemePreference(preference);
    _themePreference = preference;
    notifyListeners();
  }

  Future<void> setOutfitModuleEnabled(bool enabled) async {
    if (_outfitModuleEnabled == enabled) {
      return;
    }

    await _settingsRepository.saveOutfitModuleEnabled(enabled);
    _outfitModuleEnabled = enabled;
    notifyListeners();
  }
}
