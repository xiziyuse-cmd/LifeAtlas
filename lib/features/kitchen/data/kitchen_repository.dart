import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import '../../../core/database/app_database.dart';
import '../domain/kitchen_models.dart';
import '../domain/shopping_list.dart';
import 'community_images.dart';

class KitchenRepository {
  KitchenRepository({AppDatabase? database})
    : _database = database ?? AppDatabase();
  final AppDatabase _database;

  // Retained for compatibility; fixed preset import was retired in 2.3.0.
  Future<void> initializePresets() async {}

  Future<ShoppingListState> loadShoppingList() async {
    final db = await _database.database;
    final rows = await db.query(
      'app_settings',
      where: 'setting_key = ?',
      whereArgs: ['kitchen_shopping_list'],
    );
    return rows.isEmpty
        ? const ShoppingListState()
        : ShoppingListState.decode(rows.single['setting_value'] as String);
  }

  Future<void> saveShoppingList(ShoppingListState state) async {
    final db = await _database.database;
    await db.insert('app_settings', {
      'setting_key': 'kitchen_shopping_list',
      'setting_value': state.encode(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<String> _owner(DatabaseExecutor tx) async {
    final rows = await tx.query(
      'app_settings',
      where: 'setting_key = ?',
      whereArgs: ['mobile_identity_v1'],
    );
    return rows.isEmpty
        ? ''
        : (jsonDecode(rows.first['setting_value'] as String) as Map)['ownerId']
              as String;
  }

  Future<List<Recipe>> listRecipes() async {
    final db = await _database.database;
    final rows = await db.rawQuery(
      'SELECT r.*, (SELECT COUNT(*) FROM cooking_record c WHERE c.recipe_id = r.id) AS cook_count FROM recipe r WHERE is_deleted = 0 AND (source_type != \'public\' OR public_active = 1) AND (source_type = \'public\' OR owner_id = ? OR owner_id = \'\') ORDER BY id DESC',
      [await _owner(db)],
    );
    final result = <Recipe>[];
    for (final row in rows) {
      final id = row['id'] as int;
      final materials = await db.query(
        'recipe_material',
        where: 'recipe_id = ?',
        whereArgs: [id],
        orderBy: 'sort, id',
      );
      final seasonings = await db.query(
        'recipe_seasoning',
        where: 'recipe_id = ?',
        whereArgs: [id],
        orderBy: 'sort, id',
      );
      final steps = await db.query(
        'recipe_step',
        where: 'recipe_id = ?',
        whereArgs: [id],
        orderBy: 'sort, id',
      );
      result.add(
        Recipe.fromMap(
          {
            'name': row['name'],
            'image': row['image'],
            'categories': jsonDecode(row['category'] as String),
            'difficulty': row['difficulty'],
            'cookTime': row['cook_time'],
            'materials': materials,
            'seasonings': seasonings,
            'steps': steps
                .map(
                  (s) => {
                    ...s,
                    'name': s['step_name'],
                    'parallelWithPrevious': s['parallel_with_previous'] == 1,
                    'materials': jsonDecode(s['materials'] as String),
                    'seasonings': jsonDecode(s['seasonings'] as String),
                  },
                )
                .toList(),
          },
          id: id,
          sourceType: row['source_type'] as String,
          cookCount: row['cook_count'] as int,
        ),
      );
    }
    return result;
  }

  Future<int> saveRecipe(Recipe recipe) async {
    recipe.validate();
    final db = await _database.database;
    if (recipe.id != null) {
      final current = await db.query(
        'recipe',
        where: 'id = ?',
        whereArgs: [recipe.id],
      );
      if (current.isNotEmpty &&
          current.first['source_type'] == 'public' &&
          recipe.image.isNotEmpty) {
        recipe = Recipe.fromMap(
          {
            ...recipe.toMap(),
            'image': await CommunityImages.personalCopy(recipe.image),
          },
          id: recipe.id,
          sourceType: recipe.sourceType,
        );
      }
    }
    return db.transaction(
      (tx) => _save(
        tx,
        recipe,
        source: recipe.sourceType == 'ai' ? 'ai' : 'personal',
      ),
    );
  }

  Future<int> _save(
    DatabaseExecutor tx,
    Recipe recipe, {
    String source = 'personal',
    bool copyPreset = true,
  }) async {
    final now = DateTime.now().toIso8601String();
    final values = {
      'name': recipe.name.trim(),
      'image': recipe.image,
      'category': jsonEncode(recipe.categories),
      'difficulty': recipe.difficulty,
      'cook_time': recipe.totalDuration,
      'source_type': source,
      'update_time': now,
      'owner_id': source == 'public' ? '' : await _owner(tx),
    };
    var id = recipe.id;
    if (id != null) {
      final current = await tx.query(
        'recipe',
        where: 'id = ? AND is_deleted = 0',
        whereArgs: [id],
      );
      if (current.isEmpty) {
        throw StateError('菜谱已删除，请返回刷新');
      }
      if (current.first['owner_id'] != '' &&
          current.first['owner_id'] != await _owner(tx)) {
        throw StateError('无法编辑其他用户的菜谱');
      }
      if (copyPreset &&
          ['preset', 'public'].contains(current.first['source_type'])) {
        id = null;
      }
    }
    if (id == null) {
      id = await tx.insert('recipe', {...values, 'create_time': now});
    } else {
      await tx.update('recipe', values, where: 'id = ?', whereArgs: [id]);
      for (final table in [
        'recipe_material',
        'recipe_seasoning',
        'recipe_step',
      ]) {
        await tx.delete(table, where: 'recipe_id = ?', whereArgs: [id]);
      }
    }
    for (final entry in {
      'recipe_material': recipe.materials,
      'recipe_seasoning': recipe.seasonings,
    }.entries) {
      for (final m in entry.value) {
        await tx.insert(entry.key, {...m.toMap(), 'recipe_id': id});
      }
    }
    for (var i = 0; i < recipe.steps.length; i++) {
      final s = recipe.steps[i];
      await tx.insert('recipe_step', {
        'recipe_id': id,
        'step_name': s.name,
        'content': s.content,
        'duration': s.duration,
        'parallel_with_previous': i > 0 && s.parallelWithPrevious ? 1 : 0,
        'sort': i,
        'materials': jsonEncode(s.materials),
        'seasonings': jsonEncode(s.seasonings),
        'image': s.image,
        'video': s.video,
      });
    }
    if (source != 'public') {
      await tx.rawInsert(
        'INSERT OR REPLACE INTO recipe_sync_queue(recipe_id,deleted,version) VALUES(?,0,?)',
        [id, now],
      );
    }
    return id;
  }

  Future<void> applyPublicRecipes(List<Map<String, dynamic>> values) async {
    final recipes = values.map((v) {
      final r = Recipe.fromMap(v, sourceType: 'public');
      r.validate();
      return r;
    }).toList();
    final db = await _database.database;
    await db.transaction((tx) async {
      await tx.update(
        'recipe',
        {'public_active': 0},
        where: 'source_type = ?',
        whereArgs: ['public'],
      );
      for (var i = 0; i < values.length; i++) {
        final v = values[i],
            old = await tx.query(
              'recipe',
              where: 'public_id = ? AND source_type = ?',
              whereArgs: [v['publicId'], 'public'],
              limit: 1,
            );
        final r = Recipe.fromMap(
          recipes[i].toMap(),
          id: old.isEmpty ? null : old.first['id'] as int,
          sourceType: 'public',
        );
        if (old.isNotEmpty && old.first['is_deleted'] == 1) {
          continue;
        }
        final id = await _save(tx, r, source: 'public', copyPreset: false);
        await tx.update(
          'recipe',
          {
            'public_id': v['publicId'],
            'public_revision': v['revision'],
            'public_active': 1,
          },
          where: 'id = ?',
          whereArgs: [id],
        );
      }
    });
  }

  Future<void> deleteRecipe(int id) async {
    final db = await _database.database;
    await db.transaction((tx) async {
      final rows = await tx.query('recipe', where: 'id = ?', whereArgs: [id]);
      if (rows.isEmpty) {
        return;
      }
      if (rows.first['owner_id'] != '' &&
          rows.first['owner_id'] != await _owner(tx)) {
        throw StateError('无法删除其他用户的菜谱');
      }
      await tx.update(
        'recipe',
        {'is_deleted': 1},
        where: 'id = ?',
        whereArgs: [id],
      );
      if (rows.first['source_type'] != 'public') {
        await tx.rawInsert(
          'INSERT OR REPLACE INTO recipe_sync_queue(recipe_id,deleted,version) VALUES(?,1,?)',
          [id, DateTime.now().toIso8601String()],
        );
      }
    });
  }

  Future<List<InventoryItem>>
  listInventory() async => (await (await _database.database).query(
    'ingredient_inventory',
    orderBy:
        'CASE WHEN expire_date IS NULL THEN 1 ELSE 0 END, expire_date ASC, id DESC',
  )).map(InventoryItem.fromMap).toList();
  Future<List<FoodBaseInfo>> listFoodBaseInfo() async =>
      (await (await _database.database).query(
        'food_base_info',
        orderBy: 'category, name',
      )).map(FoodBaseInfo.fromMap).toList();
  Future<void> saveInventory(InventoryItem item) async {
    if (item.name.trim().isEmpty ||
        item.unit.trim().isEmpty ||
        !item.amount.isFinite ||
        item.amount < 0) {
      throw const FormatException('请填写食材名称、非负数量和单位');
    }
    if (item.shelfLifeDays != null && item.shelfLifeDays! <= 0) {
      throw const FormatException('保质期需要填写正整数天数');
    }
    final db = await _database.database;
    final values = {
      ...item.toMap(),
      'name': item.name.trim(),
      'unit': item.unit.trim(),
      'update_time': DateTime.now().toIso8601String(),
    };
    if (item.id == null) {
      await db.insert('ingredient_inventory', values);
    } else {
      await db.update(
        'ingredient_inventory',
        values,
        where: 'id = ?',
        whereArgs: [item.id],
      );
    }
  }

  Future<void> deleteInventory(int id) async => (await _database.database)
      .delete('ingredient_inventory', where: 'id = ?', whereArgs: [id]);
  Future<void> saveRecord(CookingRecord record) async {
    if (record.score < 1 || record.score > 5) {
      throw const FormatException('评分须为 1－5 星');
    }
    final db = await _database.database;
    await db.insert('cooking_record', {
      'recipe_id': record.recipeId,
      'recipe_name': record.recipeName,
      'image': record.image,
      'score': record.score,
      'remark': record.remark,
      'create_time': record.date.toIso8601String(),
    });
  }

  Future<List<CookingRecord>> listRecords() async =>
      (await (await _database.database).query(
            'cooking_record',
            orderBy: 'create_time DESC, id DESC',
          ))
          .map(
            (m) => CookingRecord(
              id: m['id'] as int,
              recipeId: m['recipe_id'] as int,
              recipeName: m['recipe_name'] as String,
              date: DateTime.parse(m['create_time'] as String),
              image: m['image'] as String,
              score: m['score'] as int,
              remark: m['remark'] as String,
            ),
          )
          .toList();
}
