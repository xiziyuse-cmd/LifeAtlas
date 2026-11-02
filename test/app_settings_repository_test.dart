import 'package:flutter_test/flutter_test.dart';
import 'package:lifeatlas/core/settings/app_settings.dart';
import 'package:lifeatlas/core/settings/sqlite_app_settings_repository.dart';

import 'support/test_database.dart';

void main() {
  test('profile gender persists in app settings', () async {
    final database = await openTestAppDatabase();
    addTearDown(database.close);
    final repository = SqliteAppSettingsRepository(database);

    expect((await repository.load()).profileGender, ProfileGender.unspecified);
    await repository.saveProfileGender(ProfileGender.female);
    expect((await repository.load()).profileGender, ProfileGender.female);
  });

  test('theme palette persists independently from brightness mode', () async {
    final database = await openTestAppDatabase();
    addTearDown(database.close);
    final repository = SqliteAppSettingsRepository(database);
    await repository.saveThemePreference(AppThemePreference.dark);
    await repository.saveThemePalette(AppThemePalette.milkPudding);
    final settings = await repository.load();
    expect(settings.themePreference, AppThemePreference.dark);
    expect(settings.themePalette, AppThemePalette.milkPudding);
  });
}
