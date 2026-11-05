import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeatlas/app/app_controller.dart';
import 'package:lifeatlas/core/auth/ai_auth_session.dart';
import 'package:lifeatlas/core/settings/app_settings.dart';
import 'package:lifeatlas/core/settings/app_settings_repository.dart';
import 'package:lifeatlas/core/theme/app_theme.dart';
import 'package:lifeatlas/features/profile/data/body_vault.dart';
import 'package:lifeatlas/features/profile/data/body_password_reset.dart';
import 'package:lifeatlas/features/profile/presentation/body_profile_page.dart';
import 'package:lifeatlas/features/profile/presentation/profile_page.dart';
import 'package:lifeatlas/features/profile/presentation/ai_auth_page.dart';
import 'package:lifeatlas/features/kitchen/data/kitchen_repository.dart';
import 'package:lifeatlas/features/kitchen/data/kitchen_ai_service.dart';
import 'package:lifeatlas/features/kitchen/domain/kitchen_models.dart';
import 'package:lifeatlas/features/kitchen/presentation/kitchen_page.dart';
import 'package:lifeatlas/features/updates/app_update_notice.dart';
import 'package:lifeatlas/features/updates/app_update_service.dart';
import 'body_vault_test.dart' show MemoryBodyApi;
import 'support/test_database.dart';

class _Settings extends Fake implements AppSettingsRepository {
  @override
  Future<AppSettings> load() async => const AppSettings();
}

class _Tokens implements AiTokenStore {
  @override
  Future<String?> read() async => null;
  @override
  Future<void> clear() async {}
  @override
  Future<void> write(String value) async {}
}

class _AI extends Fake implements KitchenAiService {}

Recipe _recipe(int id, String source) => Recipe(
  id: id,
  name: '$source测试菜谱',
  sourceType: source,
  materials: const [RecipeMaterial(name: '鸡蛋', amount: 1, unit: '个')],
  steps: const [RecipeStep(name: '炒制', content: '炒熟', duration: 5)],
);

class _Recipes extends KitchenRepository {
  @override
  Future<List<Recipe>> listRecipes() async => [
    _recipe(1, 'public'),
    _recipe(2, 'personal'),
    _recipe(3, 'ai'),
  ];
  @override
  Future<List<InventoryItem>> listInventory() async => [];
}

Map<String, dynamic> legacy() =>
    jsonDecode(File('test/fixtures/body_vault_v1.json').readAsStringSync())
        as Map<String, dynamic>;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'real v1 fixture migrates with old password, preserves archived preferences and removes recovery wrapper',
    () async {
      final original = legacy();
      expect(original['version'], 1);
      expect(original.containsKey('recovery'), true);
      final api = MemoryBodyApi()..value = original;
      final v = BodyVault(api: api);
      await expectLater(v.unlock('wrong-password'), throwsStateError);
      expect(api.value, original);
      expect(v.unlocked, false);
      await v.unlock('legacy-password');
      expect(v.records.single.values, {
        '身高': '170',
        '常穿上衣尺码': 'M',
        '上装偏好': '宽松',
      });
      expect((api.value as Map)['version'], 2);
      expect((api.value as Map).containsKey('recovery'), false);
      expect(jsonEncode(api.value), isNot(contains('legacy-test-note')));
      await v.changePassword('new-password');
      v.lock();
      await v.unlock('new-password');
      expect(v.records.single.values['常穿上衣尺码'], 'M');
    },
  );
  test(
    'failed migration leaves the original encrypted archive readable and locked',
    () async {
      final original = legacy();
      final api = MemoryBodyApi()
        ..value = original
        ..fail = true;
      final v = BodyVault(api: api);
      await expectLater(v.unlock('legacy-password'), throwsStateError);
      expect(api.value, original);
      expect(v.unlocked, false);
      expect(v.records, isEmpty);
      api.fail = false;
      await v.unlock('legacy-password');
      expect(v.records.single.id, 'legacy');
    },
  );
  test(
    'phone reset placeholder rejects every operation without changing or unlocking an archive',
    () async {
      const service = UnconfiguredBodyPasswordReset();
      final api = MemoryBodyApi()..value = legacy();
      final old = jsonEncode(api.value);
      final v = BodyVault(api: api);
      final unavailable = throwsA(
        isA<BodyResetException>().having(
          (e) => e.reason,
          'reason',
          BodyResetFailure.unavailable,
        ),
      );
      await expectLater(service.requestCode(), unavailable);
      await expectLater(
        service.verifyCode(requestId: 'not-real', code: '123456'),
        unavailable,
      );
      await expectLater(
        service.resetPassword(
          authorization: BodyResetAuthorization(
            token: 'not-real',
            expiresAt: DateTime(2026),
          ),
          newPassword: 'new-password',
        ),
        unavailable,
      );
      expect(jsonEncode(api.value), old);
      expect(v.unlocked, false);
    },
  );

  testWidgets(
    'my entries have only names, compact height and the update dot survives',
    (tester) async {
      final controller = AppController(_Settings());
      await controller.initialize();
      final notice = AppUpdateNotice(supported: false);
      notice.observe(
        AppRelease(
          version: '2.5.3',
          build: 41,
          minSdk: 24,
          notes: '',
          size: 1024,
          sha256: 'a' * 64,
          url: Uri.parse('https://example.test/?download=1'),
        ),
        currentBuild: 40,
        sdk: 35,
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ProfilePage(controller: controller, updateNotice: notice),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('个人资料功能将在后续阶段完善'), findsNothing);
      final modules = find.byKey(const ValueKey('profile-modules-entry'));
      expect(tester.getSize(modules).height, inInclusiveRange(48, 56));
      for (final tile in tester.widgetList<ListTile>(find.byType(ListTile))) {
        expect(tile.subtitle, isNull);
      }
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('profile-about-entry')),
        200,
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('profile-update-dot')), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      controller.dispose();
      notice.dispose();
    },
  );

  testWidgets(
    'AI account hides credential explanation but retains password input',
    (tester) async {
      final session = AiAuthSession(
        authBaseUrl: 'https://example.test/v1/auth',
        tokenStore: _Tokens(),
      );
      await session.initialize();
      await tester.pumpWidget(MaterialApp(home: AiAuthPage(session: session)));
      await tester.pumpAndSettle();
      expect(find.textContaining('账号凭据只发送'), findsNothing);
      expect(find.widgetWithText(TextFormField, '账号'), findsOneWidget);
      expect(
        tester.widget<TextFormField>(find.widgetWithText(TextFormField, '密码')),
        isNotNull,
      );
      await tester.pumpWidget(const SizedBox.shrink());
      session.dispose();
    },
  );

  testWidgets(
    'first setup is spacious at large text with keyboard, validates and creates no recovery dialog',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 740));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final controller = AppController(_Settings());
      await controller.initialize();
      final api = MemoryBodyApi();
      final v = BodyVault(api: api);
      await tester.pumpWidget(
        MaterialApp(
          builder: (c, child) => MediaQuery(
            data: MediaQuery.of(c).copyWith(
              textScaler: TextScaler.linear(1.4),
              viewInsets: const EdgeInsets.only(bottom: 240),
            ),
            child: child!,
          ),
          home: BodyProfilePage(controller: controller, vault: v),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('设置身材密码'), findsOneWidget);
      final password = find.byKey(const ValueKey('body-password')),
          confirm = find.byKey(const ValueKey('body-confirm'));
      expect(
        tester.getTopLeft(confirm).dy - tester.getBottomLeft(password).dy,
        greaterThanOrEqualTo(20),
      );
      await tester.enterText(password, 'password123');
      await tester.enterText(confirm, 'different');
      await tester.pumpAndSettle();
      final button = find.byKey(const ValueKey('body-password-submit'));
      await Scrollable.ensureVisible(tester.element(button), alignment: 0.5);
      await tester.pumpAndSettle();
      await tester.tap(button);
      await tester.pumpAndSettle();
      expect(find.text('两次密码不一致'), findsOneWidget);
      await tester.enterText(confirm, 'password123');
      await tester.ensureVisible(button);
      final press = tester.widget<FilledButton>(button).onPressed!;
      await tester.runAsync(() async {
        press();
        for (var i = 0; i < 400 && !v.unlocked; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 25));
        }
      });
      await tester.pumpAndSettle();
      expect(v.unlocked, true);
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.textContaining('恢复码'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      controller.dispose();
    },
  );

  testWidgets(
    'old preferences stay hidden in latest/history/form and are preserved when correcting measurements',
    (tester) async {
      final controller = AppController(_Settings());
      await controller.initialize();
      final api = MemoryBodyApi()..value = legacy();
      final v = BodyVault(api: api);
      await tester.runAsync(() => v.unlock('legacy-password'));
      await tester.pumpWidget(
        MaterialApp(
          home: BodyProfilePage(controller: controller, vault: v),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('常穿上衣尺码'), findsNothing);
      expect(find.textContaining('宽松'), findsNothing);
      await tester.tap(find.byTooltip('历史记录'));
      await tester.pumpAndSettle();
      expect(find.textContaining('常穿上衣尺码'), findsNothing);
      await tester.tap(find.text('修正这条记录'));
      await tester.pumpAndSettle();
      expect(find.text('尺码与偏好'), findsNothing);
      expect(find.text('常穿上衣尺码'), findsNothing);
      await tester.tap(find.byTooltip('怎么量身高'));
      await tester.pumpAndSettle();
      expect(find.text('脱鞋站直，从头顶至地面。'), findsOneWidget);
      expect(find.textContaining('示意：'), findsNothing);
      await tester.tap(find.text('知道了'));
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextField, '170'), '171');
      await tester.scrollUntilVisible(
        find.text('保存记录'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('保存记录'));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pumpAndSettle();
      expect(v.records.single.values['身高'], '171');
      expect(v.records.single.values['常穿上衣尺码'], 'M');
      expect(v.records.single.values['上装偏好'], '宽松');
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('锁定'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('忘记密码'));
      await tester.tap(find.text('忘记密码'));
      await tester.pumpAndSettle();
      expect(find.text(bodyResetUnavailableMessage), findsOneWidget);
      expect(v.unlocked, false);
      expect(find.textContaining('恢复码'), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
      controller.dispose();
    },
  );

  testWidgets(
    'only public recipes have source labels in all palettes, narrow large text and details',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 740));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      for (final palette in AppThemePalette.values) {
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light(palette),
            builder: (c, child) => MediaQuery(
              data: MediaQuery.of(
                c,
              ).copyWith(textScaler: TextScaler.linear(1.6)),
              child: child!,
            ),
            home: Scaffold(
              body: KitchenPage(repository: _Recipes(), aiService: _AI()),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('recipe-public-1')), findsOneWidget);
        expect(find.byKey(const ValueKey('recipe-public-2')), findsNothing);
        expect(find.byKey(const ValueKey('recipe-public-3')), findsNothing);
        expect(tester.takeException(), isNull);
      }
      await tester.tap(find.byKey(const ValueKey('recipe-card-1')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.byKey(const ValueKey('recipe-public-source')),
      );
      expect(find.text('来源：公共库'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('recipe-card-2')));
      await tester.pumpAndSettle();
      expect(find.text('来源：公共库'), findsNothing);
    },
  );

  test(
    'saving a public recipe creates a personal copy without changing public provenance',
    () async {
      final db = await openTestAppDatabase();
      addTearDown(db.close);
      final repo = KitchenRepository(database: db);
      await repo.applyPublicRecipes([
        {
          ..._recipe(1, 'public').toMap(),
          'publicId': 'public-test',
          'revision': 1,
        },
      ]);
      final public = (await repo.listRecipes()).singleWhere(
        (r) => r.sourceType == 'public',
      );
      final id = await repo.saveRecipe(public);
      expect(id, isNot(public.id));
      final rows = await repo.listRecipes();
      expect(rows.singleWhere((r) => r.id == id).sourceType, 'personal');
      expect(rows.singleWhere((r) => r.id == public.id).sourceType, 'public');
    },
  );
}
