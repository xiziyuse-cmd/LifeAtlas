import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lifeatlas/core/database/app_database.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  test('v1 wardrobe data migrates additively to v5', () async {
    sqfliteFfiInit();
    final directory = await Directory.systemTemp.createTemp(
      'lifeatlas-migration-',
    );
    final databasePath = p.join(directory.path, 'migration.db');
    addTearDown(() async {
      await databaseFactoryFfi.deleteDatabase(databasePath);
      if (await directory.exists()) {
        await directory.delete(recursive: true);
      }
    });

    final v1 = await databaseFactoryFfi.openDatabase(
      databasePath,
      options: OpenDatabaseOptions(version: 1, onCreate: _createV1Schema),
    );
    final timestamp = DateTime.utc(2026, 8, 16).toIso8601String();
    final clothingId = await v1.insert('clothing_items', {
      'name': '旧外套',
      'image_path': 'images/coat.jpg',
      'brand': 'Legacy Brand',
      'category': '外套',
      'season_tags': '["秋","冬"]',
      'chest_circumference': 108,
      'created_at': timestamp,
      'updated_at': timestamp,
    });
    final secondId = await v1.insert('clothing_items', {
      'name': '旧连体裤',
      'image_path': 'images/trousers.jpg',
      'category': '连体裤',
      'season_tags': '["秋"]',
      'created_at': timestamp,
      'updated_at': timestamp,
    });
    final setId = await v1.insert('outfit_sets', {
      'name': '旧套装',
      'season_tags': '["秋"]',
      'created_at': timestamp,
      'updated_at': timestamp,
    });
    await v1.insert('outfit_set_items', {
      'outfit_set_id': setId,
      'clothing_item_id': clothingId,
    });
    await v1.insert('outfit_set_items', {
      'outfit_set_id': setId,
      'clothing_item_id': secondId,
    });
    final dailyId = await v1.insert('daily_outfit_records', {
      'record_date': '2026-08-16T00:00:00.000',
      'recorded_at': timestamp,
    });
    await v1.insert('daily_outfit_items', {
      'daily_outfit_id': dailyId,
      'clothing_item_id': clothingId,
    });
    await v1.close();

    final appDatabase = AppDatabase(
      factory: databaseFactoryFfi,
      databasePath: databasePath,
    );
    addTearDown(appDatabase.close);
    final migrated = await appDatabase.database;

    expect(await migrated.getVersion(), AppDatabase.databaseVersion);
    final clothingColumns = await migrated.rawQuery(
      'PRAGMA table_info(clothing_items)',
    );
    expect(clothingColumns.map((row) => row['name']), contains('brand_id'));
    expect(clothingColumns.map((row) => row['name']), contains('category_id'));
    final dailyColumns = await migrated.rawQuery(
      'PRAGMA table_info(daily_outfit_records)',
    );
    expect(dailyColumns.map((row) => row['name']), contains('updated_at'));
    expect(
      dailyColumns.map((row) => row['name']),
      contains('temperature_applied_at'),
    );

    final migratedClothing = await migrated.query(
      'clothing_items',
      where: 'id = ?',
      whereArgs: [clothingId],
      limit: 1,
    );
    expect(migratedClothing.single['brand'], 'Legacy Brand');
    expect(migratedClothing.single['brand_id'], isNotNull);
    expect(migratedClothing.single['category_id'], isNotNull);
    final positions = await migrated.query(
      'outfit_set_items',
      orderBy: 'position ASC',
    );
    expect(positions.map((row) => row['position']), [0, 1]);
    expect(
      await migrated.query('clothing_categories', where: 'is_default = 1'),
      hasLength(13),
    );
    expect(
      await migrated.query(
        'clothing_categories',
        where: 'name IN (?, ?)',
        whereArgs: ['连体裤', '饰品'],
      ),
      isEmpty,
    );
    final remainingCategoryNames = (await migrated.query(
      'clothing_categories',
      columns: const ['name'],
    )).map((row) => row['name']);
    for (final retiredName in ['腰带', '戒指', '手链', '手表', '眼镜', '袜子', '内搭']) {
      expect(remainingCategoryNames, isNot(contains(retiredName)));
    }
    final retiredCategoryClothing = await migrated.query(
      'clothing_items',
      where: 'id = ?',
      whereArgs: [secondId],
      limit: 1,
    );
    expect(retiredCategoryClothing.single['category'], '连体裤');
    expect(retiredCategoryClothing.single['category_id'], isNull);
    final parameterRows = await migrated.query(
      'clothing_parameter_values',
      where: 'clothing_item_id = ? AND parameter_key = ?',
      whereArgs: [clothingId, 'chest_circumference'],
    );
    expect(parameterRows.single['number_value'], 108);
    expect(parameterRows.single['source'], 'legacy_migration');
    expect(
      await migrated.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' "
        "AND name IN ('preorder_items', 'preorder_analyses')",
      ),
      hasLength(2),
    );
    expect(await migrated.rawQuery('PRAGMA foreign_key_check'), isEmpty);
  });
}

Future<void> _createV1Schema(Database database, int version) async {
  final batch = database.batch()
    ..execute('''
      CREATE TABLE clothing_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        image_path TEXT NOT NULL,
        brand TEXT,
        category TEXT,
        season_tags TEXT NOT NULL DEFAULT '[]',
        color TEXT,
        material TEXT,
        size TEXT,
        clothing_length REAL,
        shoulder_width REAL,
        chest_circumference REAL,
        sleeve_length REAL,
        waist_circumference REAL,
        hip_circumference REAL,
        trouser_length REAL,
        purchase_price REAL,
        purchase_date TEXT,
        notes TEXT,
        is_deleted INTEGER NOT NULL DEFAULT 0,
        wear_count INTEGER NOT NULL DEFAULT 0,
        min_worn_temperature REAL,
        max_worn_temperature REAL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''')
    ..execute('''
      CREATE TABLE outfit_sets (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        season_tags TEXT NOT NULL DEFAULT '[]',
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''')
    ..execute('''
      CREATE TABLE outfit_set_items (
        outfit_set_id INTEGER NOT NULL,
        clothing_item_id INTEGER NOT NULL,
        PRIMARY KEY (outfit_set_id, clothing_item_id),
        FOREIGN KEY (outfit_set_id) REFERENCES outfit_sets(id)
          ON DELETE CASCADE,
        FOREIGN KEY (clothing_item_id) REFERENCES clothing_items(id)
      )
    ''')
    ..execute('''
      CREATE TABLE daily_outfit_records (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        record_date TEXT NOT NULL UNIQUE,
        recorded_at TEXT NOT NULL,
        weather_type TEXT,
        min_temperature REAL,
        max_temperature REAL
      )
    ''')
    ..execute('''
      CREATE TABLE daily_outfit_items (
        daily_outfit_id INTEGER NOT NULL,
        clothing_item_id INTEGER NOT NULL,
        PRIMARY KEY (daily_outfit_id, clothing_item_id),
        FOREIGN KEY (daily_outfit_id) REFERENCES daily_outfit_records(id)
          ON DELETE CASCADE,
        FOREIGN KEY (clothing_item_id) REFERENCES clothing_items(id)
      )
    ''');
  await batch.commit(noResult: true);
}
