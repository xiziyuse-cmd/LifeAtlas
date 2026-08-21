import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../features/home/data/home_repository.dart';
import '../features/navigation/presentation/app_shell.dart';
import '../features/wardrobe/data/clothing_image_parameter_service.dart';
import '../features/wardrobe/data/wardrobe_image_service.dart';
import '../features/wardrobe/data/wardrobe_repository.dart';
import 'app_controller.dart';

class LifeAtlasApp extends StatelessWidget {
  const LifeAtlasApp({
    super.key,
    required this.controller,
    this.homeRepository,
    this.wardrobeRepository,
    this.wardrobeImageService,
    this.clothingImageParameterService =
        const UnconfiguredClothingImageParameterService(),
  });

  final AppController controller;
  final HomeRepository? homeRepository;
  final WardrobeRepository? wardrobeRepository;
  final WardrobeImageService? wardrobeImageService;
  final ClothingImageParameterService clothingImageParameterService;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        return MaterialApp(
          title: 'LifeAtlas',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: controller.themePreference.themeMode,
          home: AppShell(
            controller: controller,
            homeRepository: homeRepository,
            wardrobeRepository: wardrobeRepository,
            wardrobeImageService: wardrobeImageService,
            clothingImageParameterService: clothingImageParameterService,
          ),
        );
      },
    );
  }
}
