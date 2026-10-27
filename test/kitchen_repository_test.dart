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
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'v5 database upgrades without seeding recipes or losing settings',
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
        'food_base_info',
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
      expect(await repository.listRecipes(), isEmpty);
      expect(
        (await SqliteAppSettingsRepository(
          upgraded,
        ).load()).outfitModuleEnabled,
        true,
      );
      expect(await (await upgraded.database).getVersion(), 8);
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
    'v8 migration clears recipes and related records but preserves inventory',
    () async {
      sqfliteFfiInit();
      final directory = await Directory.systemTemp.createTemp(
        'kitchen-v8-migration-',
      );
      final path = '${directory.path}/app.db';
      final old = AppDatabase(factory: databaseFactoryFfi, databasePath: path);
      final oldDb = await old.database;
      final now = DateTime(2026, 10, 27).toIso8601String();
      final recipeId = await oldDb.insert('recipe', {
        'name': '旧菜谱',
        'image': '',
        'category': '["家常菜"]',
        'difficulty': '简单',
        'cook_time': 10,
        'source_type': 'personal',
        'create_time': now,
        'update_time': now,
      });
      for (final table in ['recipe_material', 'recipe_seasoning']) {
        await oldDb.insert(table, {
          'recipe_id': recipeId,
          'name': '鸡蛋',
          'amount': 1,
          'unit': '个',
          'remark': '',
          'stage': '准备阶段',
          'sort': 1,
        });
      }
      await oldDb.insert('recipe_step', {
        'recipe_id': recipeId,
        'step_name': '煎蛋',
        'content': '加热后煎熟',
        'duration': 10,
        'sort': 0,
        'materials': '[]',
        'seasonings': '[]',
        'image': '',
        'video': '',
      });
      await oldDb.insert('cooking_record', {
        'recipe_id': recipeId,
        'recipe_name': '旧菜谱',
        'image': '',
        'score': 4,
        'remark': '',
        'create_time': now,
      });
      await oldDb.insert('ingredient_inventory', {
        'name': '库存鸡蛋',
        'amount': 3,
        'unit': '个',
        'remark': '',
        'expire_date': null,
        'update_time': now,
        'purchase_date': '2026-10-27',
        'shelf_life_days': 14,
      });
      await oldDb.setVersion(7);
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
      final db = await upgraded.database;
      expect(await repository.listRecipes(), isEmpty);
      for (final table in [
        'recipe',
        'recipe_material',
        'recipe_seasoning',
        'recipe_step',
        'cooking_record',
      ]) {
        expect(await db.query(table), isEmpty, reason: table);
      }
      expect((await repository.listInventory()).single.name, '库存鸡蛋');
      expect(await db.query('food_base_info'), isNotEmpty);
      expect(await db.rawQuery('PRAGMA foreign_key_check'), isEmpty);
    },
  );

  test(
    'new recipes do not require preset data and sum step durations',
    () async {
      final db = await openTestAppDatabase();
      addTearDown(db.close);
      final repository = KitchenRepository(database: db);
      expect(await repository.listRecipes(), isEmpty);

      final id = await repository.saveRecipe(
        Recipe(
          name: '我的菜谱',
          cookTime: 999,
          materials: const [RecipeMaterial(name: '鸡蛋', amount: 2, unit: '个')],
          steps: const [
            RecipeStep(name: '准备', content: '打蛋', duration: 4),
            RecipeStep(name: '烹饪', content: '炒熟', duration: 8),
          ],
        ),
      );
      final saved = (await repository.listRecipes()).single;
      expect(saved.id, id);
      expect(saved.totalDuration, 12);
      expect(saved.toMap()['cookTime'], 12);
      expect(
        (await (await db.database).query('recipe')).single['cook_time'],
        12,
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

  test(
    'food defaults are separate and inventory is sorted by expiry',
    () async {
      final db = await openTestAppDatabase();
      addTearDown(db.close);
      final repository = KitchenRepository(database: db);
      final defaults = await repository.listFoodBaseInfo();
      expect(
        defaults.firstWhere((food) => food.name == '鸡蛋').defaultShelfLife,
        30,
      );
      final now = DateTime(2026, 9, 9);
      await repository.saveInventory(
        InventoryItem(
          name: '鸡蛋',
          amount: 8,
          unit: '个',
          purchaseDate: now,
          shelfLifeDays: 21,
          expireDate: DateTime(2026, 9, 30),
          updatedAt: now,
        ),
      );
      await repository.saveInventory(
        InventoryItem(
          name: '土豆',
          amount: 2,
          unit: '个',
          purchaseDate: now,
          shelfLifeDays: 3,
          expireDate: DateTime(2026, 9, 12),
          updatedAt: now,
        ),
      );
      final inventory = await repository.listInventory();
      expect(inventory.map((item) => item.name), ['土豆', '鸡蛋']);
      expect(inventory.last.shelfLifeDays, 21);
      expect(
        defaults.firstWhere((food) => food.name == '鸡蛋').defaultShelfLife,
        30,
      );
    },
  );

  test('freshness boundaries use calendar days', () {
    final now = DateTime(2026, 9, 9, 22);
    InventoryItem item(int offset) => InventoryItem(
      name: '测试',
      amount: 1,
      unit: '个',
      expireDate: DateTime(2026, 9, 9).add(Duration(days: offset)),
      updatedAt: now,
    );
    expect(item(4).remainingDays(now), 4);
    expect(item(4).freshness, InventoryFreshness.fresh);
    expect(item(3).freshness, InventoryFreshness.nearExpiry);
    expect(item(0).freshness, InventoryFreshness.today);
    expect(item(-1).freshness, InventoryFreshness.expired);
  });

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
