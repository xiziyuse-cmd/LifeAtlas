import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeatlas/app/app_controller.dart';
import 'package:lifeatlas/app/life_atlas_app.dart';
import 'package:lifeatlas/core/auth/ai_auth_session.dart';
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
    expect(find.text('开启板块后会在底部导航中新增入口；关闭不会删除已经保存的数据。'), findsNothing);
    expect(find.text('衣柜、套装、穿搭记录与预购管理'), findsOneWidget);
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

  testWidgets('profile opens the AI service login page', (tester) async {
    final repository = _MemoryAppSettingsRepository();
    final controller = AppController(repository);
    final session = AiAuthSession(
      authBaseUrl: 'https://example.test/v1/auth',
      tokenStore: _MemoryAiTokenStore(),
    );
    addTearDown(session.dispose);
    await controller.initialize();
    await session.initialize();

    await tester.pumpWidget(
      LifeAtlasApp(controller: controller, aiAuthSession: session),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('我的'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('profile-ai-auth-entry')));
    await tester.pumpAndSettle();

    expect(find.text('AI 服务账号'), findsWidgets);
    expect(find.byKey(const ValueKey('ai-auth-username')), findsOneWidget);
    expect(find.byKey(const ValueKey('ai-auth-password')), findsOneWidget);
    expect(find.byKey(const ValueKey('ai-auth-login')), findsOneWidget);
  });

  testWidgets('body profile saves gender selection', (tester) async {
    final repository = _MemoryAppSettingsRepository();
    final controller = AppController(repository);
    await controller.initialize();

    await tester.pumpWidget(LifeAtlasApp(controller: controller));
    await tester.pumpAndSettle();
    await tester.tap(find.text('我的'));
    await tester.pumpAndSettle();
    final bodyEntry = find.byKey(const ValueKey('profile-body-entry'));
    await tester.ensureVisible(bodyEntry);
    await tester.pumpAndSettle();
    await tester.tap(bodyEntry);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('profile-gender-female')));
    await tester.pumpAndSettle();

    expect(controller.profileGender, ProfileGender.female);
    expect(repository.settings.profileGender, ProfileGender.female);
    expect(find.text('穿搭中将显示内衣、裙装和连衣裙。'), findsOneWidget);
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
      profileGender: settings.profileGender,
    );
  }

  @override
  Future<void> saveProfileGender(ProfileGender gender) async {
    settings = AppSettings(
      themePreference: settings.themePreference,
      outfitModuleEnabled: settings.outfitModuleEnabled,
      profileGender: gender,
    );
  }

  @override
  Future<void> saveThemePreference(AppThemePreference preference) async {
    settings = AppSettings(
      themePreference: preference,
      outfitModuleEnabled: settings.outfitModuleEnabled,
      profileGender: settings.profileGender,
    );
  }
}

class _MemoryAiTokenStore implements AiTokenStore {
  String? value;

  @override
  Future<void> clear() async => value = null;

  @override
  Future<String?> read() async => value;

  @override
  Future<void> write(String value) async => this.value = value;
}
