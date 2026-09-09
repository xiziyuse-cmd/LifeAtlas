import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import '../../../core/database/app_database.dart';
import '../domain/kitchen_models.dart';
import 'preset_recipes.dart';

class KitchenRepository {
  KitchenRepository({AppDatabase? database})
    : _database = database ?? AppDatabase();
  final AppDatabase _database;

  Future<void> ensurePresets() async {
    final db = await _database.database;
    await db.transaction((tx) async {
      final marker = await tx.query(
        'app_settings',
        where: 'setting_key = ?',
        whereArgs: ['kitchen_presets_v1'],
      );
      if (marker.isNotEmpty) return;
      for (final recipe in presetRecipes) {
        await _save(tx, recipe, source: 'preset');
      }
      await tx.insert('app_settings', {
        'setting_key': 'kitchen_presets_v1',
        'setting_value': '1',
      });
    });
  }

  Future<List<Recipe>> listRecipes() async {
    await ensurePresets();
    final db = await _database.database;
    final rows = await db.rawQuery(
      'SELECT r.*, (SELECT COUNT(*) FROM cooking_record c WHERE c.recipe_id = r.id) AS cook_count FROM recipe r WHERE is_deleted = 0 ORDER BY id DESC',
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
  }) async {
    final now = DateTime.now().toIso8601String();
    final values = {
      'name': recipe.name.trim(),
      'image': recipe.image,
      'category': jsonEncode(recipe.categories),
      'difficulty': recipe.difficulty,
      'cook_time': recipe.cookTime,
      'source_type': source,
      'update_time': now,
    };
    var id = recipe.id;
    if (id != null) {
      final current = await tx.query(
        'recipe',
        where: 'id = ? AND is_deleted = 0',
        whereArgs: [id],
      );
      if (current.isEmpty) throw StateError('菜谱已删除，请返回刷新');
      if (current.first['source_type'] == 'preset') id = null;
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
        'sort': i,
        'materials': jsonEncode(s.materials),
        'seasonings': jsonEncode(s.seasonings),
        'image': s.image,
        'video': s.video,
      });
    }
    return id;
  }

  Future<void> deleteRecipe(int id) async {
    final db = await _database.database;
    await db.update(
      'recipe',
      {'is_deleted': 1},
      where: 'id = ? AND source_type != ?',
      whereArgs: [id, 'preset'],
    );
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
