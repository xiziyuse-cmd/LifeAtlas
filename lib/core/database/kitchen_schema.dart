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

Future<void> upgradeKitchenSchemaToV7(Database db) async {
  await db.execute('''CREATE TABLE food_base_info (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL UNIQUE,
    category TEXT NOT NULL,
    default_shelf_life INTEGER NOT NULL CHECK(default_shelf_life > 0),
    shelf_life_unit TEXT NOT NULL DEFAULT 'day',
    storage_type TEXT NOT NULL,
    create_time TEXT NOT NULL,
    update_time TEXT NOT NULL
  )''');
  await db.execute(
    'ALTER TABLE ingredient_inventory ADD COLUMN purchase_date TEXT',
  );
  await db.execute(
    'ALTER TABLE ingredient_inventory ADD COLUMN shelf_life_days INTEGER',
  );
  await db.execute(
    'CREATE INDEX ingredient_inventory_expiry ON ingredient_inventory(expire_date)',
  );
  final now = DateTime.now().toIso8601String();
  final foods = <(String, String, int, String)>[
    ('牛奶', '乳制品', 7, '冷藏'),
    ('鸡蛋', '蛋类', 30, '冷藏'),
    ('西红柿', '蔬菜', 7, '冷藏'),
    ('土豆', '蔬菜', 30, '阴凉干燥'),
    ('青椒', '蔬菜', 7, '冷藏'),
    ('鸡胸肉', '肉类', 2, '冷藏'),
    ('猪肉', '肉类', 2, '冷藏'),
    ('豆腐', '豆制品', 3, '冷藏'),
    ('面包', '主食', 5, '常温'),
    ('酸奶', '乳制品', 14, '冷藏'),
    ('苹果', '水果', 14, '冷藏'),
    ('香蕉', '水果', 5, '常温'),
  ];
  for (final food in foods) {
    await db.insert('food_base_info', {
      'name': food.$1,
      'category': food.$2,
      'default_shelf_life': food.$3,
      'shelf_life_unit': 'day',
      'storage_type': food.$4,
      'create_time': now,
      'update_time': now,
    });
  }
}
