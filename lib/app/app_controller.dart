import 'package:flutter/foundation.dart';

import '../core/settings/app_settings.dart';
import '../core/settings/app_settings_repository.dart';

class AppController extends ChangeNotifier {
  AppController(this._settingsRepository);

  final AppSettingsRepository _settingsRepository;

  AppThemePreference _themePreference = AppThemePreference.system;
  AppThemePalette _themePalette = AppThemePalette.defaultTheme;
  bool _outfitModuleEnabled = false;
  ProfileGender _profileGender = ProfileGender.unspecified;
  bool _initialized = false;
  bool _kitchenModuleEnabled = false;
  bool get kitchenModuleEnabled => _kitchenModuleEnabled;
  Future<void> setKitchenModuleEnabled(bool enabled) async {
    await _settingsRepository.saveKitchenModuleEnabled(enabled);
    _kitchenModuleEnabled = enabled;
    notifyListeners();
  }

  AppThemePreference get themePreference => _themePreference;
  AppThemePalette get themePalette => _themePalette;
  bool get outfitModuleEnabled => _outfitModuleEnabled;
  ProfileGender get profileGender => _profileGender;
  bool get initialized => _initialized;

  Future<void> initialize() async {
    final settings = await _settingsRepository.load();
    _themePreference = settings.themePreference;
    _themePalette = settings.themePalette;
    _outfitModuleEnabled = settings.outfitModuleEnabled;
    _kitchenModuleEnabled = settings.kitchenModuleEnabled;
    _profileGender = settings.profileGender;
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

  Future<void> setThemePalette(AppThemePalette palette) async {
    if (_themePalette == palette) return;
    await _settingsRepository.saveThemePalette(palette);
    _themePalette = palette;
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

  Future<void> setProfileGender(ProfileGender gender) async {
    if (_profileGender == gender) {
      return;
    }
    await _settingsRepository.saveProfileGender(gender);
    _profileGender = gender;
    notifyListeners();
  }
}
