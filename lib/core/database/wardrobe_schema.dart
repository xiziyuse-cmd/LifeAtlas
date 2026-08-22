import 'package:sqflite/sqflite.dart';

const defaultClothingCategoryNames = <String>[
  '外套',
  '内搭',
  '上衣',
  '长裤',
  '短裤',
  '裙装',
  '连衣裙',
  '连体裤',
  '内衣',
  '家居服',
  '鞋',
  '包',
  '腰带',
  '帽子',
  '围巾',
  '项链',
  '戒指',
  '手链',
  '手表',
  '眼镜',
  '袜子',
  '饰品',
];

String normalizeWardrobeCatalogName(String value) {
  return value.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();
}

Future<void> upgradeWardrobeSchemaToV2(Database database) async {
  await database.execute('''
    CREATE TABLE IF NOT EXISTS clothing_categories (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL,
      normalized_name TEXT NOT NULL UNIQUE,
      is_default INTEGER NOT NULL DEFAULT 0,
      sort_order INTEGER NOT NULL DEFAULT 1000,
      created_at TEXT NOT NULL
    )
  ''');
  await database.execute('''
    CREATE TABLE IF NOT EXISTS clothing_brands (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL,
      normalized_name TEXT NOT NULL UNIQUE,
      is_default INTEGER NOT NULL DEFAULT 0,
      sort_order INTEGER NOT NULL DEFAULT 1000,
      created_at TEXT NOT NULL
    )
  ''');

  await _addColumnIfMissing(
    database,
    table: 'clothing_items',
    column: 'brand_id',
    definition: 'INTEGER REFERENCES clothing_brands(id) ON DELETE SET NULL',
  );
  await _addColumnIfMissing(
    database,
    table: 'clothing_items',
    column: 'category_id',
    definition: 'INTEGER REFERENCES clothing_categories(id) ON DELETE SET NULL',
  );
  await _addColumnIfMissing(
    database,
    table: 'outfit_set_items',
    column: 'position',
    definition: 'INTEGER NOT NULL DEFAULT 0',
  );
  await _addColumnIfMissing(
    database,
    table: 'daily_outfit_records',
    column: 'updated_at',
    definition: 'TEXT',
  );
  await _addColumnIfMissing(
    database,
    table: 'daily_outfit_records',
    column: 'temperature_applied_at',
    definition: 'TEXT',
  );

  await database.execute('''
    CREATE TABLE IF NOT EXISTS preorder_items (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT,
      image_path TEXT NOT NULL,
      brand TEXT,
      category TEXT,
      brand_id INTEGER,
      category_id INTEGER,
      price REAL,
      material TEXT,
      size TEXT,
      clothing_length REAL,
      shoulder_width REAL,
      chest_circumference REAL,
      sleeve_length REAL,
      waist_circumference REAL,
      hip_circumference REAL,
      trouser_length REAL,
      product_url TEXT,
      description TEXT,
      notes TEXT,
      is_purchased INTEGER NOT NULL DEFAULT 0,
      purchased_at TEXT,
      clothing_item_id INTEGER,
      is_deleted INTEGER NOT NULL DEFAULT 0,
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL,
      FOREIGN KEY (brand_id) REFERENCES clothing_brands(id)
        ON DELETE SET NULL,
      FOREIGN KEY (category_id) REFERENCES clothing_categories(id)
        ON DELETE SET NULL,
      FOREIGN KEY (clothing_item_id) REFERENCES clothing_items(id)
        ON DELETE SET NULL
    )
  ''');
  await database.execute('''
    CREATE TABLE IF NOT EXISTS preorder_analyses (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      preorder_item_id INTEGER NOT NULL,
      prompt_version TEXT NOT NULL,
      model TEXT NOT NULL,
      result_text TEXT NOT NULL,
      result_json TEXT,
      input_tokens INTEGER,
      output_tokens INTEGER,
      total_tokens INTEGER,
      analyzed_at TEXT NOT NULL,
      FOREIGN KEY (preorder_item_id) REFERENCES preorder_items(id)
        ON DELETE CASCADE
    )
  ''');

  await database.execute('''
    UPDATE daily_outfit_records
    SET updated_at = recorded_at
    WHERE updated_at IS NULL OR updated_at = ''
  ''');

  await _seedDefaultCategories(database);
  await _backfillClothingCatalogs(database);
  await _backfillOutfitPositions(database);
  await _createIndexes(database);
}

Future<void> upgradeWardrobeSchemaToV3(Database database) async {
  await database.execute('''
    CREATE TABLE IF NOT EXISTS clothing_parameter_values (
      clothing_item_id INTEGER NOT NULL,
      parameter_key TEXT NOT NULL,
      number_value REAL,
      text_value TEXT,
      unit TEXT,
      source TEXT NOT NULL DEFAULT 'manual',
      confidence REAL,
      updated_at TEXT NOT NULL,
      PRIMARY KEY (clothing_item_id, parameter_key),
      FOREIGN KEY (clothing_item_id) REFERENCES clothing_items(id)
        ON DELETE CASCADE
    )
  ''');
  await database.execute('''
    CREATE INDEX IF NOT EXISTS clothing_parameter_values_item_index
    ON clothing_parameter_values(clothing_item_id)
  ''');
  await _seedDefaultCategories(database);
  await _backfillLegacyClothingParameters(database);
}

Future<void> _backfillLegacyClothingParameters(Database database) async {
  const legacyColumns = <String>[
    'clothing_length',
    'shoulder_width',
    'chest_circumference',
    'sleeve_length',
    'waist_circumference',
    'hip_circumference',
    'trouser_length',
  ];
  final rows = await database.query(
    'clothing_items',
    columns: ['id', 'updated_at', ...legacyColumns],
  );
  for (final row in rows) {
    final itemId = row['id'] as int;
    final updatedAt = row['updated_at'] as String;
    for (final key in legacyColumns) {
      final value = (row[key] as num?)?.toDouble();
      if (value == null) {
        continue;
      }
      await database.insert('clothing_parameter_values', {
        'clothing_item_id': itemId,
        'parameter_key': key,
        'number_value': value,
        'unit': 'cm',
        'source': 'legacy_migration',
        'updated_at': updatedAt,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
    }
  }
}

Future<void> _addColumnIfMissing(
  Database database, {
  required String table,
  required String column,
  required String definition,
}) async {
  final columns = await database.rawQuery('PRAGMA table_info($table)');
  if (columns.any((row) => row['name'] == column)) {
    return;
  }
  await database.execute('ALTER TABLE $table ADD COLUMN $column $definition');
}

Future<void> _seedDefaultCategories(DatabaseExecutor database) async {
  final createdAt = DateTime.now().toUtc().toIso8601String();
  for (var index = 0; index < defaultClothingCategoryNames.length; index++) {
    final name = defaultClothingCategoryNames[index];
    await database.insert('clothing_categories', {
      'name': name,
      'normalized_name': normalizeWardrobeCatalogName(name),
      'is_default': 1,
      'sort_order': index,
      'created_at': createdAt,
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
  }
}

Future<void> _backfillClothingCatalogs(Database database) async {
  final rows = await database.query(
    'clothing_items',
    columns: const ['id', 'brand', 'category'],
  );
  for (final row in rows) {
    final brand = (row['brand'] as String?)?.trim();
    final category = (row['category'] as String?)?.trim();
    final brandId = brand == null || brand.isEmpty
        ? null
        : await _findOrCreateCatalogEntry(
            database,
            table: 'clothing_brands',
            name: brand,
          );
    final categoryId = category == null || category.isEmpty
        ? null
        : await _findOrCreateCatalogEntry(
            database,
            table: 'clothing_categories',
            name: category,
          );
    await database.update(
      'clothing_items',
      {'brand_id': brandId, 'category_id': categoryId},
      where: 'id = ?',
      whereArgs: [row['id']],
    );
  }
}

Future<int> _findOrCreateCatalogEntry(
  DatabaseExecutor database, {
  required String table,
  required String name,
}) async {
  final normalizedName = normalizeWardrobeCatalogName(name);
  final existing = await database.query(
    table,
    columns: const ['id'],
    where: 'normalized_name = ?',
    whereArgs: [normalizedName],
    limit: 1,
  );
  if (existing.isNotEmpty) {
    return existing.first['id'] as int;
  }

  return database.insert(table, {
    'name': name.trim(),
    'normalized_name': normalizedName,
    'created_at': DateTime.now().toUtc().toIso8601String(),
  });
}

Future<void> _backfillOutfitPositions(Database database) async {
  final rows = await database.query(
    'outfit_set_items',
    columns: const ['outfit_set_id', 'clothing_item_id'],
    orderBy: 'outfit_set_id ASC, clothing_item_id ASC',
  );
  int? currentSetId;
  var position = 0;
  for (final row in rows) {
    final setId = row['outfit_set_id'] as int;
    if (setId != currentSetId) {
      currentSetId = setId;
      position = 0;
    }
    await database.update(
      'outfit_set_items',
      {'position': position++},
      where: 'outfit_set_id = ? AND clothing_item_id = ?',
      whereArgs: [setId, row['clothing_item_id']],
    );
  }
}

Future<void> _createIndexes(DatabaseExecutor database) async {
  final batch = database.batch()
    ..execute('''
      CREATE INDEX IF NOT EXISTS clothing_items_active_filter_index
      ON clothing_items(is_deleted, category_id, brand_id)
    ''')
    ..execute('''
      CREATE UNIQUE INDEX IF NOT EXISTS outfit_set_items_position_index
      ON outfit_set_items(outfit_set_id, position)
    ''')
    ..execute('''
      CREATE INDEX IF NOT EXISTS outfit_set_items_clothing_index
      ON outfit_set_items(clothing_item_id, outfit_set_id)
    ''')
    ..execute('''
      CREATE INDEX IF NOT EXISTS daily_outfit_items_clothing_index
      ON daily_outfit_items(clothing_item_id, daily_outfit_id)
    ''')
    ..execute('''
      CREATE INDEX IF NOT EXISTS preorder_items_active_index
      ON preorder_items(is_deleted, is_purchased, created_at)
    ''')
    ..execute('''
      CREATE INDEX IF NOT EXISTS preorder_analyses_item_time_index
      ON preorder_analyses(preorder_item_id, analyzed_at DESC)
    ''');
  await batch.commit(noResult: true);
}
