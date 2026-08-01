import 'package:sqflite/sqflite.dart';

import '../database/app_database.dart';
import 'app_settings.dart';
import 'app_settings_repository.dart';

class SqliteAppSettingsRepository implements AppSettingsRepository {
  SqliteAppSettingsRepository(this._appDatabase);

  static const _themeKey = 'theme_mode';
  static const _outfitModuleKey = 'outfit';

  final AppDatabase _appDatabase;

  @override
  Future<AppSettings> load() async {
    final database = await _appDatabase.database;

    final themeRows = await database.query(
      'app_settings',
      columns: ['setting_value'],
      where: 'setting_key = ?',
      whereArgs: [_themeKey],
      limit: 1,
    );
    final moduleRows = await database.query(
      'module_settings',
      columns: ['enabled'],
      where: 'module_key = ?',
      whereArgs: [_outfitModuleKey],
      limit: 1,
    );

    final themeValue = themeRows.isEmpty
        ? null
        : themeRows.first['setting_value'] as String?;
    final outfitEnabled =
        moduleRows.isNotEmpty && moduleRows.first['enabled'] == 1;

    return AppSettings(
      themePreference: AppThemePreference.fromStorage(themeValue),
      outfitModuleEnabled: outfitEnabled,
    );
  }

  @override
  Future<void> saveThemePreference(AppThemePreference preference) async {
    final database = await _appDatabase.database;
    await database.insert('app_settings', {
      'setting_key': _themeKey,
      'setting_value': preference.name,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  @override
  Future<void> saveOutfitModuleEnabled(bool enabled) async {
    final database = await _appDatabase.database;
    await database.insert('module_settings', {
      'module_key': _outfitModuleKey,
      'enabled': enabled ? 1 : 0,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }
}
