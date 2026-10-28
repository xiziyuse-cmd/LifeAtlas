import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeatlas/core/database/app_database.dart';
import 'package:lifeatlas/features/kitchen/data/kitchen_ai_service.dart';
import 'package:lifeatlas/features/kitchen/data/kitchen_repository.dart';
import 'package:lifeatlas/features/kitchen/domain/kitchen_models.dart';
import 'package:lifeatlas/features/kitchen/domain/recipe_ingredient_extractor.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'support/test_database.dart';

Map<String, ExtractedRecipeItem> _items(String text) => {
  for (final item in extractRecipeIngredients(text)) item.item.name: item,
};
RecipeStep _step(String content) => RecipeStep(
  name: '制作',
  content: content,
  duration: 5,
  parallelWithPrevious: true,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'line peppers and millet chili are extracted as seasonings without confusing millet',
    () {
      final items = _items('线椒20g切碎，加入小米辣2根和小米100g');
      expect(items['线椒']!.seasoning, true);
      expect(items['线椒']!.item.quantity, '20g');
      expect(items['小米辣']!.seasoning, true);
      expect(items['小米辣']!.item.quantity, '2根');
      expect(items['小米']!.seasoning, false);
      expect(items['小米']!.item.quantity, '100g');
    },
  );
  test(
    'extracts food and seasonings with explicit amounts and blank quantities',
    () {
      final items = _items('鸡肉100g切块，加盐1勺和胡椒粉，腌制20分钟');
      expect(items.keys, ['鸡肉', '盐', '胡椒粉']);
      expect(items['鸡肉']!.seasoning, false);
      expect(items['鸡肉']!.item.quantity, '100g');
      expect(items['盐']!.seasoning, true);
      expect(items['盐']!.item.quantity, '1勺');
      expect(items['胡椒粉']!.item.amount, isNull);
      expect(items['胡椒粉']!.item.unit, '');
      expect(items['胡椒粉']!.item.quantity, '');
    },
  );
  test(
    'reads prefix suffix Chinese numbers fractions decimals and fullwidth digits',
    () {
      final items = _items('取一百克鸡肉，加入半勺生抽和1/2小勺盐，放入土豆５０克，加入1.5勺蚝油');
      expect(items['鸡肉']!.item.quantity, '100g');
      expect(items['生抽']!.item.quantity, '0.5勺');
      expect(items['盐']!.item.quantity, '0.5小勺');
      expect(items['土豆']!.item.quantity, '50g');
      expect(items['蚝油']!.item.quantity, '1.5勺');
    },
  );
  test(
    'does not invent quantities from cooking time or include tools and negations',
    () {
      expect(_items('锅中焯水20分钟，用勺子搅拌，不加盐，不要放糖，放入锅中翻炒'), isEmpty);
      final items = _items('将鸡肉煮20分钟，加入适量盐，180度烤10分钟');
      expect(items.keys, ['鸡肉', '盐']);
      expect(
        items.values.every((e) => e.item.amount == null && e.item.unit.isEmpty),
        true,
      );
      expect(_items('盐1-2勺，鸡肉约100-200g')['盐']!.item.amount, isNull);
    },
  );
  test(
    'uses longest food names and handles explicit uncommon names and English boundaries',
    () {
      final items = _items('鸡胸肉100g，黑胡椒粉半勺，加入藜蒿50g翻炒，放入木瓜');
      expect(items.keys.toSet(), {'鸡胸肉', '黑胡椒粉', '藜蒿', '木瓜'});
      expect(items['藜蒿']!.item.quantity, '50g');
      expect(items['木瓜']!.item.amount, isNull);
      final english = _items(
        'Add chicken 100g, salt 1 tsp and pepper. Boil for 20 minutes',
      );
      expect(english.keys, ['chicken', 'salt', 'pepper']);
      expect(english['salt']!.item.quantity, '1小勺');
      expect(english['pepper']!.item.amount, isNull);
      expect(_items('boiled for 5 minutes'), isEmpty);
    },
  );
  test(
    'repeated step saves deduplicate without increasing ingredient quantities',
    () {
      final first = mergeStepIngredients(
        _step('加入盐1勺，盐1勺拌匀'),
        materials: [],
        seasonings: [],
      );
      expect(first.seasonings.single.quantity, '1勺');
      expect(first.step.seasonings, ['盐']);
      final second = mergeStepIngredients(
        first.step,
        materials: first.materials,
        seasonings: first.seasonings,
      );
      expect(second.seasonings.single.quantity, '1勺');
      expect(second.changed, 0);
      expect(second.step.parallelWithPrevious, true);
    },
  );
  test(
    'fills blanks but preserves existing amounts units and user classification',
    () {
      final result = mergeStepIngredients(
        _step('鸡肉100g，加盐1勺、胡椒粉2g和姜'),
        materials: const [
          RecipeMaterial(name: '鸡肉', amount: 300, unit: 'g'),
          RecipeMaterial(name: '姜'),
        ],
        seasonings: const [
          RecipeMaterial(name: '盐'),
          RecipeMaterial(name: '胡椒粉', unit: '勺'),
        ],
      );
      expect(result.materials.first.quantity, '300g');
      expect(result.materials.map((i) => i.name), ['鸡肉', '姜']);
      expect(result.seasonings.first.quantity, '1勺');
      expect(result.seasonings.last.amount, isNull);
      expect(result.seasonings.last.unit, '勺');
      expect(result.step.materials.toSet(), {'鸡肉', '姜'});
      expect(result.step.seasonings.toSet(), {'盐', '胡椒粉'});
    },
  );
  test(
    'name only materials serialize and validate while invalid amounts still fail',
    () {
      const material = RecipeMaterial(name: '胡椒粉');
      expect(RecipeMaterial.fromMap(material.toMap()).amount, isNull);
      expect(material.quantity, '');
      Recipe recipe(RecipeMaterial item) =>
          Recipe(name: '测试', materials: [item], steps: [_step('拌匀')]);
      expect(() => recipe(material).validate(), returnsNormally);
      for (final value in [0.0, -1.0, double.nan, double.infinity]) {
        expect(
          () => recipe(
            RecipeMaterial(name: '盐', amount: value, unit: 'g'),
          ).validate(),
          throwsFormatException,
        );
      }
      expect(
        () => recipe(const RecipeMaterial(name: '盐', amount: 1)).validate(),
        throwsFormatException,
      );
      expect(
        inventoryAvailability(material, [
          InventoryItem(
            name: '胡椒粉',
            amount: 5,
            unit: 'g',
            updatedAt: DateTime.now(),
          ),
        ]),
        '已有 · 用量待确认',
      );
    },
  );
  test(
    'unknown quantities persist as null and can be filled after reloading',
    () async {
      final db = await openTestAppDatabase();
      addTearDown(db.close);
      final repository = KitchenRepository(database: db);
      final extracted = mergeStepIngredients(
        _step('鸡肉100g，加盐1勺和胡椒粉'),
        materials: [],
        seasonings: [],
      );
      final id = await repository.saveRecipe(
        Recipe(
          name: '测试',
          materials: extracted.materials,
          seasonings: extracted.seasonings,
          steps: [extracted.step],
        ),
      );
      final saved = (await repository.listRecipes()).single;
      expect(saved.seasonings.last.name, '胡椒粉');
      expect(saved.seasonings.last.amount, isNull);
      expect(saved.seasonings.last.unit, '');
      expect(
        (await (await db.database).query(
          'recipe_seasoning',
          where: 'name = ?',
          whereArgs: ['胡椒粉'],
        )).single['amount'],
        isNull,
      );
      final filled = mergeStepIngredients(
        _step('胡椒粉2g'),
        materials: saved.materials,
        seasonings: saved.seasonings,
      );
      await repository.saveRecipe(
        Recipe(
          id: id,
          name: saved.name,
          materials: filled.materials,
          seasonings: filled.seasonings,
          steps: [filled.step],
        ),
      );
      expect(
        (await repository.listRecipes()).single.seasonings.last.quantity,
        '2g',
      );
    },
  );
  test(
    'v9 to v10 preserves data IDs and parallel flags and allows missing amounts',
    () async {
      sqfliteFfiInit();
      final dir = await Directory.systemTemp.createTemp('ingredients-v10-');
      final path = '${dir.path}/app.db';
      final old = AppDatabase(factory: databaseFactoryFfi, databasePath: path);
      final repository = KitchenRepository(database: old);
      final id = await repository.saveRecipe(
        const Recipe(
          name: '旧菜谱',
          materials: [RecipeMaterial(name: '鸡肉', amount: 100, unit: 'g')],
          seasonings: [RecipeMaterial(name: '盐', amount: 1, unit: '勺')],
          steps: [
            RecipeStep(name: '腌制', content: '等待', duration: 20),
            RecipeStep(
              name: '切菜',
              content: '准备',
              duration: 22,
              parallelWithPrevious: true,
            ),
          ],
        ),
      );
      await repository.saveInventory(
        InventoryItem(
          name: '鸡肉',
          amount: 500,
          unit: 'g',
          updatedAt: DateTime.now(),
        ),
      );
      await repository.saveRecord(
        CookingRecord(recipeId: id, recipeName: '旧菜谱', date: DateTime.now()),
      );
      final oldDb = await old.database;
      await oldDb.insert('app_settings', {
        'setting_key': 'test',
        'setting_value': 'keep',
      });
      for (final table in ['recipe_material', 'recipe_seasoning']) {
        await oldDb.execute(
          'CREATE TABLE ${table}_old (id INTEGER PRIMARY KEY AUTOINCREMENT, recipe_id INTEGER NOT NULL REFERENCES recipe(id) ON DELETE CASCADE, name TEXT NOT NULL, amount REAL NOT NULL CHECK(amount > 0), unit TEXT NOT NULL, remark TEXT NOT NULL, stage TEXT NOT NULL, sort INTEGER NOT NULL)',
        );
        await oldDb.execute('INSERT INTO ${table}_old SELECT * FROM $table');
        await oldDb.execute('DROP TABLE $table');
        await oldDb.execute('ALTER TABLE ${table}_old RENAME TO $table');
      }
      await oldDb.setVersion(9);
      await expectLater(
        oldDb.insert('recipe_material', {
          'recipe_id': id,
          'name': '未知',
          'amount': null,
          'unit': '',
          'remark': '',
          'stage': '准备阶段',
          'sort': 2,
        }),
        throwsA(isA<DatabaseException>()),
      );
      final tables = [
        'recipe',
        'recipe_material',
        'recipe_seasoning',
        'recipe_step',
        'ingredient_inventory',
        'cooking_record',
        'app_settings',
        'food_base_info',
      ];
      final snapshots = <String, List<Map<String, Object?>>>{};
      for (final table in tables) {
        snapshots[table] = await oldDb.query(table);
      }
      await old.close();
      final upgraded = AppDatabase(
        factory: databaseFactoryFfi,
        databasePath: path,
      );
      addTearDown(() async {
        await upgraded.close();
        await databaseFactoryFfi.deleteDatabase(path);
        await dir.delete();
      });
      final db = await upgraded.database;
      expect(await db.getVersion(), AppDatabase.databaseVersion);
      for (final table in tables) {
        expect(await db.query(table), snapshots[table], reason: table);
      }
      final loaded = (await KitchenRepository(
        database: upgraded,
      ).listRecipes()).single;
      expect(loaded.totalDuration, 22);
      expect(loaded.steps.last.parallelWithPrevious, true);
      await db.insert('recipe_material', {
        'recipe_id': id,
        'name': '未知',
        'amount': null,
        'unit': '',
        'remark': '',
        'stage': '准备阶段',
        'sort': 2,
      });
      expect(await db.rawQuery('PRAGMA foreign_key_check'), isEmpty);
    },
  );
}
