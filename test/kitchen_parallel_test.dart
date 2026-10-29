import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeatlas/core/database/app_database.dart';
import 'package:lifeatlas/features/kitchen/data/kitchen_repository.dart';
import 'package:lifeatlas/features/kitchen/domain/kitchen_models.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'support/test_database.dart';

RecipeStep _step(int duration, [bool parallel = false]) => RecipeStep(
  name: '步骤',
  content: '操作',
  duration: duration,
  parallelWithPrevious: parallel,
);

Recipe _recipe({int? id, bool parallel = true}) => Recipe(
  id: id,
  name: '并行测试菜谱',
  materials: const [RecipeMaterial(name: '鸡肉', amount: 100, unit: 'g')],
  steps: [
    const RecipeStep(name: '腌制', content: '等待入味', duration: 20),
    RecipeStep(
      name: '切菜',
      content: '切好配菜',
      duration: 22,
      parallelWithPrevious: parallel,
    ),
    const RecipeStep(name: '炒菜', content: '炒熟', duration: 5),
  ],
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'parallel duration takes each group maximum and adds sequential groups',
    () {
      expect(recipeDuration([]), 0);
      expect(recipeDuration([_step(20), _step(22)]), 42);
      expect(recipeDuration([_step(20), _step(22, true)]), 22);
      expect(_recipe().totalDuration, 27);
      expect(recipeDuration([_step(20), _step(22, true), _step(30, true)]), 30);
      expect(
        recipeDuration([_step(20), _step(22, true), _step(5), _step(7, true)]),
        29,
      );
      expect(recipeDuration([_step(20, true), _step(0, true), _step(5)]), 25);
      expect(recipeDuration([_step(0), _step(22, true)]), 22);
      expect(recipeStepGroups(_recipe().steps).map((g) => g.length), [2, 1]);
    },
  );

  test(
    'old JSON defaults to sequential and new JSON preserves parallel flags',
    () {
      final old = RecipeStep.fromMap({
        'name': '旧步骤',
        'content': '操作',
        'duration': 20,
      });
      expect(old.parallelWithPrevious, false);
      final recipe = _recipe();
      final restored = Recipe.fromMap(recipe.toMap());
      expect(restored.totalDuration, 27);
      expect(restored.steps.map((s) => s.parallelWithPrevious), [
        false,
        true,
        false,
      ]);
      expect(old.copyWith(parallelWithPrevious: true).name, old.name);
      expect(recipe.toMap()['cookTime'], 27);
    },
  );

  test(
    'save reload and edit persist group flags and normalized first step',
    () async {
      final db = await openTestAppDatabase();
      addTearDown(db.close);
      final repository = KitchenRepository(database: db);
      final source = _recipe();
      final id = await repository.saveRecipe(
        Recipe(
          name: source.name,
          materials: source.materials,
          steps: [
            source.steps.first.copyWith(parallelWithPrevious: true),
            ...source.steps.skip(1),
          ],
        ),
      );
      var loaded = (await repository.listRecipes()).single;
      expect(loaded.totalDuration, 27);
      expect(loaded.steps.map((s) => s.parallelWithPrevious), [
        false,
        true,
        false,
      ]);
      expect(
        (await (await db.database).query('recipe')).single['cook_time'],
        27,
      );
      await repository.saveRecipe(_recipe(id: id, parallel: false));
      loaded = (await repository.listRecipes()).single;
      expect(loaded.totalDuration, 47);
      expect(loaded.steps.any((s) => s.parallelWithPrevious), false);
    },
  );

  test(
    'v8 to v9 preserves all recipe inventory record and settings data',
    () async {
      sqfliteFfiInit();
      final directory = await Directory.systemTemp.createTemp('parallel-v9-');
      final path = '${directory.path}/app.db';
      final old = AppDatabase(factory: databaseFactoryFfi, databasePath: path);
      final repository = KitchenRepository(database: old);
      final id = await repository.saveRecipe(_recipe(parallel: false));
      await repository.saveInventory(
        InventoryItem(
          name: '鸡肉',
          amount: 500,
          unit: 'g',
          updatedAt: DateTime(2026, 10, 27),
        ),
      );
      await repository.saveRecord(
        CookingRecord(
          recipeId: id,
          recipeName: '并行测试菜谱',
          date: DateTime(2026, 10, 27),
        ),
      );
      final oldDb = await old.database;
      await oldDb.insert('app_settings', {
        'setting_key': 'theme_mode',
        'setting_value': 'dark',
      });
      await oldDb.execute(
        'ALTER TABLE recipe_step DROP COLUMN parallel_with_previous',
      );
      await oldDb.setVersion(8);
      final tables = [
        'recipe',
        'recipe_step',
        'recipe_material',
        'recipe_seasoning',
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
        await directory.delete();
      });
      final db = await upgraded.database;
      expect(await db.getVersion(), AppDatabase.databaseVersion);
      for (final table in tables) {
        final rows = await db.query(table);
        final normalized = rows.map((row) {
          final copy = Map<String, Object?>.from(row);
          if (table == 'recipe_step') {
            expect(copy.remove('parallel_with_previous'), 0);
          }
          return copy;
        }).toList();
        expect(normalized, snapshots[table], reason: table);
      }
      final saved = (await KitchenRepository(
        database: upgraded,
      ).listRecipes()).single;
      expect(saved.totalDuration, 47);
      expect(saved.steps.any((s) => s.parallelWithPrevious), false);
      expect(await db.rawQuery('PRAGMA foreign_key_check'), isEmpty);
    },
  );
}
