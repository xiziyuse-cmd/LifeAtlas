import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:lifeatlas/core/database/app_database.dart';
import 'package:lifeatlas/core/settings/app_settings.dart';
import 'package:lifeatlas/core/theme/app_theme.dart';
import 'package:lifeatlas/features/kitchen/data/kitchen_repository.dart';
import 'package:lifeatlas/features/kitchen/domain/kitchen_models.dart';
import 'package:lifeatlas/features/kitchen/presentation/recipe_form_page.dart';
import 'package:lifeatlas/features/kitchen/presentation/recipe_detail_page.dart';

class _Repository extends KitchenRepository {
  Recipe? saved;
  @override
  Future<int> saveRecipe(Recipe recipe) async {
    recipe.validate();
    saved = recipe;
    return 1;
  }
}

const _recipe = Recipe(
  name: '测试菜谱',
  categories: ['家常菜', '午餐', '晚餐'],
  materials: [RecipeMaterial(name: '胡萝卜', amount: 100, unit: 'g')],
  seasonings: [RecipeMaterial(name: '盐', amount: 1, unit: '勺')],
  steps: [
    RecipeStep(name: '腌制', content: '第一步描述', duration: 20),
    RecipeStep(
      name: '切菜',
      content: '第二步描述',
      duration: 22,
      parallelWithPrevious: true,
    ),
  ],
);

Future<void> _reveal(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(
    finder,
    200,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'category chips follow every theme and inline plus adds selected category without permanent input',
    (tester) async {
      for (final palette in AppThemePalette.values) {
        for (final dark in [false, true]) {
          final theme = dark ? AppTheme.dark(palette) : AppTheme.light(palette);
          await tester.pumpWidget(
            MaterialApp(
              theme: theme,
              home: RecipeFormPage(
                key: ValueKey('$palette-$dark'),
                repository: _Repository(),
                recipe: _recipe,
              ),
            ),
          );
          await _reveal(
            tester,
            find.byKey(const ValueKey('add-recipe-category')),
          );
          final chip = tester.widget<FilterChip>(
            find.widgetWithText(FilterChip, '家常菜'),
          );
          expect(
            chip.selectedColor,
            dark
                ? theme.colorScheme.primaryContainer
                : theme.colorScheme.primary,
          );
          expect(
            chip.labelStyle!.color,
            dark
                ? theme.colorScheme.onPrimaryContainer
                : theme.colorScheme.onPrimary,
          );
          expect(chip.showCheckmark, false);
          expect(find.text('午餐'), findsNothing);
          expect(find.text('晚餐'), findsNothing);
          expect(find.widgetWithText(TextField, '自定义分类'), findsNothing);
        }
      }
      final repository = _Repository();
      await tester.pumpWidget(
        MaterialApp(
          home: RecipeFormPage(
            key: const ValueKey('custom'),
            repository: repository,
            recipe: _recipe,
          ),
        ),
      );
      await _reveal(tester, find.byKey(const ValueKey('add-recipe-category')));
      await tester.tap(find.byKey(const ValueKey('add-recipe-category')));
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextField, '分类名称'), '  下饭菜  ');
      await tester.tap(find.widgetWithText(FilledButton, '确定'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<FilterChip>(find.widgetWithText(FilterChip, '下饭菜'))
            .selected,
        true,
      );
      expect(find.byType(AlertDialog), findsNothing);
      await _reveal(tester, find.text('保存菜谱'));
      await tester.tap(find.text('保存菜谱'));
      await tester.pumpAndSettle();
      expect(repository.saved!.categories, ['家常菜', '下饭菜']);
      expect(repository.saved!.totalDuration, 22);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'editor ingredients match detail font and grouped order, and removal remains usable',
    (tester) async {
      final theme = AppTheme.light(AppThemePalette.defaultTheme);
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: RecipeFormPage(repository: _Repository(), recipe: _recipe),
        ),
      );
      await _reveal(tester, find.text('盐'));
      final divider = find.byKey(
        const ValueKey('recipe-form-ingredient-divider'),
      );
      expect(divider, findsOneWidget);
      expect(find.text('食材'), findsNothing);
      expect(find.text('调料'), findsNothing);
      expect(
        tester.getCenter(find.text('胡萝卜')).dy,
        lessThan(tester.getCenter(divider).dy),
      );
      expect(
        tester.getCenter(find.text('盐')).dy,
        greaterThan(tester.getCenter(divider).dy),
      );
      expect(
        tester.getCenter(find.text('胡萝卜')).dy,
        tester.getCenter(find.text('100g')).dy,
      );
      final text = tester.widget<Text>(find.text('胡萝卜'));
      final size = DefaultTextStyle.of(
        tester.element(find.text('胡萝卜')),
      ).style.merge(text.style).fontSize;
      await tester.tap(find.byTooltip('移除盐'));
      await tester.pumpAndSettle();
      expect(find.text('盐'), findsNothing);
      expect(divider, findsNothing);
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: RecipeDetailPage(repository: _Repository(), recipe: _recipe),
        ),
      );
      await _reveal(tester, find.text('胡萝卜'));
      final detail = tester.widget<Text>(find.text('胡萝卜'));
      expect(
        DefaultTextStyle.of(
          tester.element(find.text('胡萝卜')),
        ).style.merge(detail.style).fontSize,
        size,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'step card has title and timing first, description below, and step inputs have a safe gap',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(AppThemePalette.defaultTheme),
          home: RecipeFormPage(repository: _Repository(), recipe: _recipe),
        ),
      );
      await _reveal(tester, find.text('第二步描述'));
      final title = find.text('2. 切菜'),
          duration = find.text('并行 · 22分钟'),
          description = find.text('第二步描述');
      expect(tester.getTopLeft(title).dy, tester.getTopLeft(duration).dy);
      expect(
        tester.getTopLeft(duration).dx,
        greaterThan(tester.getTopRight(title).dx),
      );
      expect(
        tester.getTopLeft(description).dy,
        greaterThan(tester.getBottomLeft(title).dy),
      );
      await tester.tap(title);
      await tester.pumpAndSettle();
      final name = find.widgetWithText(TextField, '步骤名称'),
          content = find.widgetWithText(TextField, '步骤描述');
      expect(
        tester.getTopLeft(content).dy - tester.getBottomLeft(name).dy,
        greaterThanOrEqualTo(24),
      );
      expect(
        tester.widget<TextField>(content).decoration!.alignLabelWithHint,
        true,
      );
      await tester.enterText(name, '较长的步骤名称');
      await tester.enterText(content, '编辑后的描述');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'parallel detail remains readable on narrow phone with large text',
    (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark(AppThemePalette.berryShake),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(1.5)),
            child: child!,
          ),
          home: RecipeDetailPage(repository: _Repository(), recipe: _recipe),
        ),
      );
      await _reveal(tester, find.text('22分钟'));
      expect(find.text('并行'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  test(
    'v10 upgrade adds only missing seasonings and preserves all existing records',
    () async {
      sqfliteFfiInit();
      final directory = await Directory.systemTemp.createTemp('kitchen-v11-');
      final path = '${directory.path}/app.db';
      final old = AppDatabase(factory: databaseFactoryFfi, databasePath: path);
      final id = await KitchenRepository(database: old).saveRecipe(_recipe);
      final db = await old.database;
      await db.delete('food_base_info', where: 'name = ?', whereArgs: ['线椒']);
      await db.update(
        'food_base_info',
        {'category': '我的调料', 'default_shelf_life': 11},
        where: 'name = ?',
        whereArgs: ['小米辣'],
      );
      await db.insert('app_settings', {
        'setting_key': 'preserve-test',
        'setting_value': 'keep',
      });
      final tables = [
        'recipe',
        'recipe_material',
        'recipe_seasoning',
        'recipe_step',
        'ingredient_inventory',
        'app_settings',
      ];
      final before = {for (final table in tables) table: await db.query(table)};
      await db.setVersion(10);
      await old.close();
      final upgraded = AppDatabase(
        factory: databaseFactoryFfi,
        databasePath: path,
      );
      addTearDown(() async {
        await upgraded.close();
        await databaseFactoryFfi.deleteDatabase(path);
        await directory.delete();
      });
      final current = await upgraded.database;
      expect(await current.getVersion(), 11);
      for (final table in tables) {
        expect(await current.query(table), before[table]);
      }
      expect(
        (await KitchenRepository(database: upgraded).listRecipes()).single.id,
        id,
      );
      final added = (await current.query(
        'food_base_info',
        where: 'name = ?',
        whereArgs: ['线椒'],
      )).single;
      expect(added['category'], '调料');
      expect(added['default_shelf_life'], 7);
      final existing = (await current.query(
        'food_base_info',
        where: 'name = ?',
        whereArgs: ['小米辣'],
      )).single;
      expect(existing['category'], '我的调料');
      expect(existing['default_shelf_life'], 11);
      expect(await current.rawQuery('PRAGMA foreign_key_check'), isEmpty);
    },
  );
}
