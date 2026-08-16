import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeatlas/app/app_controller.dart';
import 'package:lifeatlas/app/life_atlas_app.dart';
import 'package:lifeatlas/core/settings/app_settings.dart';
import 'package:lifeatlas/core/settings/app_settings_repository.dart';

void main() {
  testWidgets('profile module entry controls the dynamic bottom tab', (
    tester,
  ) async {
    final repository = _MemoryAppSettingsRepository();
    final controller = AppController(repository);
    await controller.initialize();

    await tester.pumpWidget(LifeAtlasApp(controller: controller));
    await tester.pumpAndSettle();

    expect(find.byType(NavigationDestination), findsNWidgets(2));
    expect(find.text('板块'), findsNothing);

    await tester.tap(find.text('我的'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('profile-outfit-switch')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('profile-modules-entry')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('modules-outfit-switch')));
    await tester.pumpAndSettle();

    expect(controller.outfitModuleEnabled, isTrue);
    expect(repository.settings.outfitModuleEnabled, isTrue);

    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(find.byType(NavigationDestination), findsNWidgets(3));
  });

  testWidgets('profile theme icon changes the theme mode', (tester) async {
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);

    final repository = _MemoryAppSettingsRepository();
    final controller = AppController(repository);
    await controller.initialize();

    await tester.pumpWidget(LifeAtlasApp(controller: controller));
    await tester.pumpAndSettle();

    await tester.tap(find.text('我的'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('theme-mode-selector')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('theme-mode-toggle')));
    await tester.pumpAndSettle();

    expect(controller.themePreference, AppThemePreference.dark);
    expect(repository.settings.themePreference, AppThemePreference.dark);
    expect(
      Theme.of(tester.element(find.byType(Scaffold).first)).brightness,
      Brightness.dark,
    );
  });

  testWidgets('bottom tab pages do not show a common app bar title', (
    tester,
  ) async {
    final repository = _MemoryAppSettingsRepository();
    final controller = AppController(repository);
    await controller.initialize();

    await tester.pumpWidget(LifeAtlasApp(controller: controller));
    await tester.pumpAndSettle();

    expect(find.byType(AppBar), findsNothing);

    await tester.tap(find.text('我的'));
    await tester.pumpAndSettle();

    expect(find.byType(AppBar), findsNothing);
  });
}

class _MemoryAppSettingsRepository implements AppSettingsRepository {
  AppSettings settings = const AppSettings();

  @override
  Future<AppSettings> load() async => settings;

  @override
  Future<void> saveOutfitModuleEnabled(bool enabled) async {
    settings = AppSettings(
      themePreference: settings.themePreference,
      outfitModuleEnabled: enabled,
    );
  }

  @override
  Future<void> saveThemePreference(AppThemePreference preference) async {
    settings = AppSettings(
      themePreference: preference,
      outfitModuleEnabled: settings.outfitModuleEnabled,
    );
  }
}
