import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

class AppDatabase {
  static const _databaseName = 'life_atlas.db';
  static const _databaseVersion = 1;

  Database? _instance;

  Future<Database> get database async {
    return _instance ??= await _open();
  }

  Future<Database> _open() async {
    final databaseDirectory = await getDatabasesPath();
    final databasePath = p.join(databaseDirectory, _databaseName);

    return openDatabase(
      databasePath,
      version: _databaseVersion,
      onConfigure: (database) async {
        await database.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: _createSchema,
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
  }

  Future<void> close() async {
    await _instance?.close();
    _instance = null;
  }
}
