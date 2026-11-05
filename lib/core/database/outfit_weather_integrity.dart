import 'package:sqflite/sqflite.dart';

/// Rebuild from confirmed daily snapshots. Legacy uncertain values are retained
/// in daily records for review, but must not continue polluting recommendations.
Future<void> rebuildOutfitTemperatures(DatabaseExecutor db) async {
  await db.execute('''
    UPDATE clothing_items SET
      min_worn_temperature = (
        SELECT MIN(r.min_temperature) FROM daily_outfit_records r
        JOIN daily_outfit_items i ON i.daily_outfit_id = r.id
        WHERE i.clothing_item_id = clothing_items.id
          AND r.weather_status = 'verified'
      ),
      max_worn_temperature = (
        SELECT MAX(r.max_temperature) FROM daily_outfit_records r
        JOIN daily_outfit_items i ON i.daily_outfit_id = r.id
        WHERE i.clothing_item_id = clothing_items.id
          AND r.weather_status = 'verified'
      )
  ''');
}

Future<void> upgradeOutfitWeatherToV14(Database db) async {
  Future<void> column(String table, String name, String definition) async {
    final columns = await db.rawQuery('PRAGMA table_info($table)');
    if (!columns.any((c) => c['name'] == name)) {
      await db.execute('ALTER TABLE $table ADD COLUMN $name $definition');
    }
  }

  final previous = await db.rawQuery('PRAGMA table_info(daily_outfit_records)');
  final alreadyMigrated = previous.any((c) => c['name'] == 'weather_status');
  for (final table in ['weather_records', 'daily_outfit_records']) {
    for (final name in ['weather_city_id', 'weather_zone']) {
      await column(table, name, 'TEXT');
    }
  }
  await column('daily_outfit_records', 'weather_source', 'TEXT');
  await column('daily_outfit_records', 'weather_fetched_at', 'TEXT');
  await column(
    'daily_outfit_records',
    'weather_status',
    "TEXT NOT NULL DEFAULT 'missing'",
  );
  // Old snapshots lack city provenance; retain them for explicit review.
  if (!alreadyMigrated) {
    await db.execute(
      "UPDATE daily_outfit_records SET weather_status = 'pending' WHERE min_temperature IS NOT NULL OR max_temperature IS NOT NULL",
    );
  }
  await rebuildOutfitTemperatures(db);
}
