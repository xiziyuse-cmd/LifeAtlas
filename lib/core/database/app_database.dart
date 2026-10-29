import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import 'wardrobe_schema.dart';
import 'kitchen_schema.dart';
import 'skincare_schema.dart';

class AppDatabase {
  static const _databaseName = 'life_atlas.db';
  static const databaseVersion = 12;

  AppDatabase({DatabaseFactory? factory, this.databasePath})
    : _databaseFactory = factory;

  AppDatabase.forTesting(Database database)
    : _databaseFactory = null,
      databasePath = null,
      _instance = database;

  final DatabaseFactory? _databaseFactory;
  final String? databasePath;
  Database? _instance;

  Future<Database> get database async {
    return _instance ??= await _open();
  }

  Future<Database> _open() async {
    final resolvedPath =
        databasePath ?? p.join(await getDatabasesPath(), _databaseName);

    final options = OpenDatabaseOptions(
      version: databaseVersion,
      onConfigure: (database) async {
        await database.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: _createSchema,
      onUpgrade: _upgradeSchema,
    );
    final factory = _databaseFactory;
    if (factory != null) {
      return factory.openDatabase(resolvedPath, options: options);
    }
    return openDatabase(
      resolvedPath,
      version: options.version,
      onConfigure: options.onConfigure,
      onCreate: options.onCreate,
      onUpgrade: options.onUpgrade,
    );
  }

  Future<void> _createSchema(Database database, int version) async {
    final batch = database.batch()
      ..execute('''
        CREATE TABLE app_settings (
          setting_key TEXT PRIMARY KEY,
          setting_value TEXT NOT NULL
        )
      ''')
      ..execute('''
        CREATE TABLE module_settings (
          module_key TEXT PRIMARY KEY,
          enabled INTEGER NOT NULL DEFAULT 0
        )
      ''')
      ..execute('''
        CREATE TABLE weather_records (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          record_date TEXT NOT NULL UNIQUE,
          region TEXT NOT NULL,
          weather_type TEXT NOT NULL,
          current_temperature REAL,
          min_temperature REAL NOT NULL,
          max_temperature REAL NOT NULL,
          recorded_at TEXT NOT NULL,
          data_source TEXT
        )
      ''')
      ..execute('''
        CREATE TABLE calendar_records (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          record_date TEXT NOT NULL,
          entry_type TEXT NOT NULL,
          text_content TEXT,
          image_paths TEXT NOT NULL DEFAULT '[]',
          created_at TEXT NOT NULL
        )
      ''')
      ..execute('''
        CREATE INDEX calendar_records_date_index
        ON calendar_records(record_date)
      ''')
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
    await upgradeWardrobeSchemaToV2(database);
    await upgradeWardrobeSchemaToV3(database);
    await upgradeWardrobeSchemaToV4(database);
    await upgradeWardrobeSchemaToV5(database);
    await upgradeKitchenSchemaToV6(database);
    await upgradeKitchenSchemaToV7(database);
    await upgradeKitchenSchemaToV8(database);
    await upgradeKitchenSchemaToV9(database);
    await upgradeKitchenSchemaToV10(database);
    await upgradeKitchenSchemaToV11(database);
    await createSkincareSchema(database);
  }

  Future<void> _upgradeSchema(
    Database database,
    int oldVersion,
    int newVersion,
  ) async {
    if (oldVersion < 2) {
      await upgradeWardrobeSchemaToV2(database);
    }
    if (oldVersion < 3) {
      await upgradeWardrobeSchemaToV3(database);
    }
    if (oldVersion < 4) {
      await upgradeWardrobeSchemaToV4(database);
    }
    if (oldVersion < 5) {
      await upgradeWardrobeSchemaToV5(database);
    }
    if (oldVersion < 6) {
      await upgradeKitchenSchemaToV6(database);
    }
    if (oldVersion < 7) {
      await upgradeKitchenSchemaToV7(database);
    }
    if (oldVersion < 8) {
      await upgradeKitchenSchemaToV8(database);
    }
    if (oldVersion < 9) {
      await upgradeKitchenSchemaToV9(database);
    }
    if (oldVersion < 10) {
      await upgradeKitchenSchemaToV10(database);
    }
    if (oldVersion < 12) {
      await createSkincareSchema(database);
    }
    if (oldVersion < 11) {
      await upgradeKitchenSchemaToV11(database);
    }
  }

  Future<void> close() async {
    await _instance?.close();
    _instance = null;
  }
}
