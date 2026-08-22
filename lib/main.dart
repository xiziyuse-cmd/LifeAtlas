import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'app/app_controller.dart';
import 'app/life_atlas_app.dart';
import 'core/config/ai_service_config.dart';
import 'core/database/app_database.dart';
import 'core/settings/sqlite_app_settings_repository.dart';
import 'features/home/data/home_repository.dart';
import 'features/wardrobe/application/outfit_memory_scheduler.dart';
import 'features/wardrobe/data/clothing_image_parameter_service.dart';
import 'features/wardrobe/data/wardrobe_image_service.dart';
import 'features/wardrobe/data/wardrobe_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final database = AppDatabase();
  final settingsRepository = SqliteAppSettingsRepository(database);
  final homeRepository = HomeRepository(database: database);
  final wardrobeRepository = WardrobeRepository(database: database);
  final wardrobeImageService = DeviceWardrobeImageService();
  final clothingImageParameterService =
      DoubaoProxyClothingImageParameterService(
        proxyUrl: AiServiceConfig.clothingAnalysisProxyUrl,
        proxyAccessToken: AiServiceConfig.proxyAccessToken,
        allowInsecureHttp: kDebugMode,
      );
  final controller = AppController(settingsRepository);
  await controller.initialize();
  final outfitMemoryScheduler = OutfitMemoryScheduler(wardrobeRepository);
  await outfitMemoryScheduler.start();

  runApp(
    LifeAtlasApp(
      controller: controller,
      homeRepository: homeRepository,
      wardrobeRepository: wardrobeRepository,
      wardrobeImageService: wardrobeImageService,
      clothingImageParameterService: clothingImageParameterService,
    ),
  );
}
