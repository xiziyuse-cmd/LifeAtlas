import 'package:sqflite/sqflite.dart';

Future<void> createSkincareSchema(DatabaseExecutor db) async {
  for (final sql in [
    'CREATE TABLE IF NOT EXISTS skincare_catalog (id TEXT PRIMARY KEY, data TEXT NOT NULL, search_text TEXT NOT NULL, barcode TEXT NOT NULL)',
    'CREATE TABLE IF NOT EXISTS skincare_settings (key TEXT PRIMARY KEY, data TEXT NOT NULL)',
    'CREATE TABLE IF NOT EXISTS skincare_products (id TEXT PRIMARY KEY, data TEXT NOT NULL)',
    'CREATE TABLE IF NOT EXISTS skincare_plans (id TEXT PRIMARY KEY, data TEXT NOT NULL, active INTEGER NOT NULL DEFAULT 0)',
    'CREATE TABLE IF NOT EXISTS skincare_executions (date TEXT NOT NULL, period TEXT NOT NULL, data TEXT NOT NULL, PRIMARY KEY(date, period))',
  ]) {
    await db.execute(sql);
  }
}
