import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeatlas/core/database/app_database.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:lifeatlas/features/kitchen/data/kitchen_repository.dart';
import 'package:lifeatlas/features/kitchen/data/kitchen_ai_service.dart';
import 'package:lifeatlas/features/kitchen/domain/kitchen_models.dart';
import 'package:lifeatlas/core/settings/sqlite_app_settings_repository.dart';
import 'support/test_database.dart';

void main() {
  test(
    'v5 database upgrades to kitchen schema without losing settings',
    () async {
      sqfliteFfiInit();
      final directory = await Directory.systemTemp.createTemp(
        'kitchen-migration-',
      );
      final path = '${directory.path}/app.db';
      final old = AppDatabase(factory: databaseFactoryFfi, databasePath: path);
      final db = await old.database;
      await db.insert('module_settings', {
        'module_key': 'outfit',
        'enabled': 1,
      });
      for (final table in [
        'cooking_record',
        'recipe_step',
        'recipe_material',
        'recipe_seasoning',
        'recipe',
        'ingredient_inventory',
      ]) {
        await db.execute('DROP TABLE $table');
      }
      await db.setVersion(5);
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
      final repository = KitchenRepository(database: upgraded);
      expect(await repository.listRecipes(), hasLength(3));
      expect(
        (await SqliteAppSettingsRepository(
          upgraded,
        ).load()).outfitModuleEnabled,
        true,
      );
      expect(await (await upgraded.database).getVersion(), 6);
    },
  );
  test('seasoning flow uses stage order and numeric addition order', () {
    final steps = stepsFromSeasonings(const [
      RecipeMaterial(name: '盐', amount: 1, unit: 'g', stage: '出锅前', sort: 3),
      RecipeMaterial(name: '生抽', amount: 5, unit: 'ml', stage: '炒制阶段', sort: 2),
      RecipeMaterial(name: '油', amount: 10, unit: 'ml', stage: '炒制阶段', sort: 1),
    ]);
    expect(steps.map((s) => s.name), ['炒制阶段', '出锅前']);
    expect(steps.first.seasonings, ['油', '生抽']);
  });
  test(
    'presets seed once, editing creates personal copy, records survive deletion',
    () async {
      final db = await openTestAppDatabase();
      addTearDown(db.close);
      final repository = KitchenRepository(database: db);
      final presets = await repository.listRecipes();
      expect(presets, hasLength(3));
      final original = presets.first;
      final id = await repository.saveRecipe(
        Recipe.fromMap(
          {...original.toMap(), 'name': '我的汤'},
          id: original.id,
          sourceType: 'preset',
        ),
      );
      expect(id, isNot(original.id));
      var recipes = await repository.listRecipes();
      expect(recipes, hasLength(4));
      expect(
        recipes.firstWhere((r) => r.id == original.id).name,
        original.name,
      );
      final personal = recipes.firstWhere((r) => r.id == id);
      expect(
        personal.steps.map((s) => s.name),
        original.steps.map((s) => s.name),
      );
      expect(
        await repository.saveRecipe(
          Recipe.fromMap({...personal.toMap(), 'name': '改名'}, id: id),
        ),
        id,
      );
      await repository.saveRecord(
        CookingRecord(
          recipeId: id,
          recipeName: '改名',
          date: DateTime(2026, 9, 7),
          score: 4,
          image: '/photo.jpg',
          remark: '好吃',
        ),
      );
      recipes = await repository.listRecipes();
      expect(recipes.firstWhere((r) => r.id == id).cookCount, 1);
      await repository.deleteRecipe(id);
      expect(await repository.listRecipes(), hasLength(3));
      expect((await repository.listRecords()).single.recipeName, '改名');
      await repository.deleteRecipe(original.id!);
      expect(await repository.listRecipes(), hasLength(3));
      expect(
        await (await db.database).rawQuery('PRAGMA foreign_key_check'),
        isEmpty,
      );
    },
  );

  test(
    'inventory validates, persists, updates, and module toggling retains data',
    () async {
      final db = await openTestAppDatabase();
      addTearDown(db.close);
      final repository = KitchenRepository(database: db);
      final settings = SqliteAppSettingsRepository(db);
      expect((await settings.load()).kitchenModuleEnabled, false);
      await settings.saveKitchenModuleEnabled(true);
      expect((await settings.load()).kitchenModuleEnabled, true);
      await repository.saveInventory(
        InventoryItem(
          name: '鸡蛋',
          amount: 8,
          unit: '个',
          remark: '冷藏',
          expireDate: DateTime(2026, 10, 1),
          updatedAt: DateTime.now(),
        ),
      );
      final egg = (await repository.listInventory()).single;
      await repository.saveInventory(
        InventoryItem(
          id: egg.id,
          name: egg.name,
          amount: 0,
          unit: egg.unit,
          updatedAt: DateTime.now(),
        ),
      );
      await settings.saveKitchenModuleEnabled(false);
      expect((await repository.listInventory()).single.amount, 0);
      await expectLater(
        repository.saveInventory(
          InventoryItem(
            name: '坏数据',
            amount: double.nan,
            unit: '个',
            updatedAt: DateTime.now(),
          ),
        ),
        throwsFormatException,
      );
      await repository.deleteInventory(egg.id!);
      expect(await repository.listInventory(), isEmpty);
    },
  );

  test('invalid recipe cannot partially overwrite existing rows', () async {
    final db = await openTestAppDatabase();
    addTearDown(db.close);
    final repository = KitchenRepository(database: db);
    final recipe = (await repository.listRecipes()).first;
    final id = await repository.saveRecipe(recipe);
    await expectLater(
      repository.saveRecipe(Recipe(id: id, name: '无效', cookTime: -1)),
      throwsFormatException,
    );
    expect(
      (await repository.listRecipes()).firstWhere((r) => r.id == id).name,
      recipe.name,
    );
  });

  test(
    'availability never assumes seasoning and handles expiry, units, and quantities',
    () {
      final now = DateTime(2026, 9, 7);
      final inventory = [
        InventoryItem(name: '鸡蛋', amount: 1, unit: '个', updatedAt: now),
        InventoryItem(
          name: '盐',
          amount: 10,
          unit: 'g',
          expireDate: DateTime(2026, 9, 6),
          updatedAt: now,
        ),
      ];
      expect(
        inventoryAvailability(
          const RecipeMaterial(name: '盐', amount: 2, unit: 'g'),
          inventory,
          now: now,
        ),
        '缺少',
      );
      expect(
        inventoryAvailability(
          const RecipeMaterial(name: '鸡蛋', amount: 2, unit: '个'),
          inventory,
          now: now,
        ),
        '数量不足',
      );
      expect(
        inventoryAvailability(
          const RecipeMaterial(name: '鸡蛋', amount: 50, unit: 'g'),
          inventory,
          now: now,
        ),
        '已有 · 单位待确认',
      );
      expect(
        inventoryAvailability(
          const RecipeMaterial(name: '鸡蛋', amount: 1, unit: '个'),
          inventory,
          now: now,
        ),
        '✓ 已有',
      );
    },
  );
}
