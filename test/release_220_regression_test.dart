import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeatlas/features/skincare/domain/skincare_models.dart';
import 'package:lifeatlas/features/skincare/domain/skincare_rules.dart';
import 'package:lifeatlas/features/skincare/presentation/skin_profile_page.dart';
import 'package:lifeatlas/features/kitchen/data/kitchen_repository.dart';
import 'package:lifeatlas/features/kitchen/domain/kitchen_models.dart';
import 'support/test_database.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'legacy profile and multiple states round trip without allowing active care',
    () {
      final old = SkinProfile(state: '干燥', goals: ['保湿补水']).toJson()
        ..remove('states');
      expect(SkinProfile.fromJson(old).states, ['干燥']);
      final profile = SkinProfile(states: ['干燥', '泛红'], goals: ['保湿补水']);
      final restored = SkinProfile.fromJson(profile.toJson());
      expect(restored.states, ['干燥', '泛红']);
      expect(SkincareRules.gentleOnly(restored), isTrue);
      expect(SkincareRules.gentleOnly(SkinProfile()), isFalse);
    },
  );
  test('fresh kitchen stays empty without administrator publication', () async {
    final db = await openTestAppDatabase();
    addTearDown(db.close);
    final repo = KitchenRepository(database: db);
    await repo.initializePresets();
    expect(await repo.listRecipes(), isEmpty);
  });
  test(
    'preset repair does not overwrite or append to personal recipes',
    () async {
      final db = await openTestAppDatabase();
      addTearDown(db.close);
      final repo = KitchenRepository(database: db);
      await repo.saveRecipe(
        const Recipe(
          name: '我的菜谱',
          materials: [RecipeMaterial(name: '青菜', amount: 100, unit: 'g')],
          steps: [RecipeStep(name: '准备', content: '洗净', duration: 1)],
        ),
      );
      await repo.initializePresets();
      expect((await repo.listRecipes()).single.name, '我的菜谱');
    },
  );
  testWidgets(
    'profile supports multiple states and target geometry stays fixed',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      SkinProfile? result;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  result = await Navigator.push<SkinProfile>(
                    context,
                    MaterialPageRoute(builder: (_) => const SkinProfilePage()),
                  );
                },
                child: const Text('编辑'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('编辑'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.widgetWithText(FilterChip, '干燥'),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.widgetWithText(FilterChip, '干燥'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilterChip, '泛红'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<FilterChip>(find.widgetWithText(FilterChip, '干燥'))
            .selected,
        isTrue,
      );
      expect(
        tester
            .widget<FilterChip>(find.widgetWithText(FilterChip, '泛红'))
            .selected,
        isTrue,
      );
      expect(
        tester
            .widget<FilterChip>(find.widgetWithText(FilterChip, '稳定'))
            .selected,
        isFalse,
      );
      final goal = find.byKey(const ValueKey('goal-保湿补水'));
      await tester.scrollUntilVisible(
        goal,
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(goal);
      await tester.pumpAndSettle();
      final before = tester.getRect(goal);
      await tester.tap(goal);
      await tester.pumpAndSettle();
      expect(tester.getRect(goal), before);
      await tester.scrollUntilVisible(
        find.text('保存档案'),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('保存档案'));
      await tester.pumpAndSettle();
      expect(result!.states.toSet(), {'干燥', '泛红'});
      expect(result!.goals, ['保湿补水']);
      expect(tester.takeException(), isNull);
    },
  );
}
