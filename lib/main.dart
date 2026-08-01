import 'package:flutter/widgets.dart';

import 'app/app_controller.dart';
import 'app/life_atlas_app.dart';
import 'core/database/app_database.dart';
import 'core/settings/sqlite_app_settings_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final database = AppDatabase();
  final settingsRepository = SqliteAppSettingsRepository(database);
  final controller = AppController(settingsRepository);
  await controller.initialize();

  runApp(LifeAtlasApp(controller: controller));
}
