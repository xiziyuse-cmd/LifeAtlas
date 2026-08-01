import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../features/navigation/presentation/app_shell.dart';
import 'app_controller.dart';

class LifeAtlasApp extends StatelessWidget {
  const LifeAtlasApp({super.key, required this.controller});

  final AppController controller;

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
          home: AppShell(controller: controller),
        );
      },
    );
  }
}
