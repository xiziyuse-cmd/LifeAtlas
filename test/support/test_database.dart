import 'package:lifeatlas/core/database/app_database.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

Future<AppDatabase> openTestAppDatabase() async {
  sqfliteFfiInit();
  final appDatabase = AppDatabase(
    factory: databaseFactoryFfi,
    databasePath: inMemoryDatabasePath,
  );
  await appDatabase.database;
  return appDatabase;
}
