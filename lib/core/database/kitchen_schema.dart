import 'package:sqflite/sqflite.dart';

Future<void> upgradeKitchenSchemaToV6(Database db) async {
  await db.execute(
    '''CREATE TABLE recipe (id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT NOT NULL, image TEXT NOT NULL, category TEXT NOT NULL, difficulty TEXT NOT NULL, cook_time INTEGER NOT NULL, source_type TEXT NOT NULL, is_deleted INTEGER NOT NULL DEFAULT 0, create_time TEXT NOT NULL, update_time TEXT NOT NULL)''',
  );
  for (final table in ['recipe_material', 'recipe_seasoning']) {
    await db.execute(
      '''CREATE TABLE $table (id INTEGER PRIMARY KEY AUTOINCREMENT, recipe_id INTEGER NOT NULL REFERENCES recipe(id) ON DELETE CASCADE, name TEXT NOT NULL, amount REAL NOT NULL CHECK(amount > 0), unit TEXT NOT NULL, remark TEXT NOT NULL, stage TEXT NOT NULL, sort INTEGER NOT NULL)''',
    );
  }
  await db.execute(
    '''CREATE TABLE recipe_step (id INTEGER PRIMARY KEY AUTOINCREMENT, recipe_id INTEGER NOT NULL REFERENCES recipe(id) ON DELETE CASCADE, step_name TEXT NOT NULL, content TEXT NOT NULL, duration INTEGER NOT NULL, sort INTEGER NOT NULL, materials TEXT NOT NULL, seasonings TEXT NOT NULL, image TEXT NOT NULL, video TEXT NOT NULL)''',
  );
  await db.execute(
    '''CREATE TABLE ingredient_inventory (id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT NOT NULL, amount REAL NOT NULL CHECK(amount >= 0), unit TEXT NOT NULL, remark TEXT NOT NULL, expire_date TEXT, update_time TEXT NOT NULL)''',
  );
  await db.execute(
    '''CREATE TABLE cooking_record (id INTEGER PRIMARY KEY AUTOINCREMENT, recipe_id INTEGER NOT NULL REFERENCES recipe(id), recipe_name TEXT NOT NULL, image TEXT NOT NULL, score INTEGER NOT NULL CHECK(score BETWEEN 1 AND 5), remark TEXT NOT NULL, create_time TEXT NOT NULL)''',
  );
  await db.execute(
    'CREATE INDEX cooking_record_recipe ON cooking_record(recipe_id)',
  );
}
