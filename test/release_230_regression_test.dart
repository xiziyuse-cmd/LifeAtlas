import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeatlas/core/database/app_database.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:lifeatlas/features/kitchen/data/recipe_cloud_sync.dart';
import 'package:lifeatlas/core/network/mobile_api.dart';
import 'package:lifeatlas/core/database/date_key_codec.dart';
import 'package:lifeatlas/features/kitchen/data/kitchen_repository.dart';
import 'package:lifeatlas/features/kitchen/domain/kitchen_models.dart';
import 'package:lifeatlas/features/home/data/weather_service.dart';
import 'support/test_database.dart';

const dish = Recipe(
  name: '我的菜',
  materials: [RecipeMaterial(name: '鸡蛋', amount: 2, unit: '个')],
  steps: [RecipeStep(name: '煎', content: '煎熟', duration: 3)],
);

class FixtureApi extends MobileApi {
  FixtureApi({required super.database});
  final values = <String, Object?>{};
  bool fail = false;
  Map<String, Object?> response = {};
  @override
  Future<Object?> setting(String key) async => values[key];
  @override
  Future<void> saveSetting(String key, Object? value) async {
    values[key] = value;
  }

  @override
  Future<Map<String, dynamic>> call(
    String action, [
    Map<String, Object?> data = const {},
  ]) async {
    if (fail) throw StateError('天气服务暂不可用');
    return Map<String, dynamic>.from(response);
  }
}

class SyncFixtureApi extends MobileApi {
  SyncFixtureApi({required super.database, required this.repository});
  final KitchenRepository repository;
  final sent = <String>[];
  bool fail = false;
  bool editWhileSending = false;
  @override
  Future<Map<String, dynamic>> call(
    String action, [
    Map<String, Object?> data = const {},
  ]) async {
    if (action == 'catalog') return {'recipes': [], 'next': null};
    if (fail) throw StateError('网络断开');
    if (action == 'upsert') {
      sent.add((data['recipe'] as Map)['name'] as String);
      if (editWhileSending) {
        editWhileSending = false;
        await repository.saveRecipe(
          Recipe.fromMap({
            ...dish.toMap(),
            'name': '同步期间的新编辑',
          }, id: data['recipeId'] as int),
        );
      }
    }
    return {'synced': true};
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'v12 upgrade preserves recipe identity, ingredients and local settings',
    () async {
      sqfliteFfiInit();
      final directory = await Directory.systemTemp.createTemp('lifeatlas-v13-');
      final path = '${directory.path}/lifeatlas.db';
      final old = AppDatabase(factory: databaseFactoryFfi, databasePath: path);
      final repo = KitchenRepository(database: old);
      final id = await repo.saveRecipe(dish);
      final connection = await old.database;
      await connection.execute('DROP TABLE recipe_sync_queue');
      for (final column in [
        'owner_id',
        'public_id',
        'public_revision',
        'public_active',
      ]) {
        await connection.execute('ALTER TABLE recipe DROP COLUMN $column');
      }
      await connection.setVersion(12);
      await old.close();
      final upgraded = AppDatabase(
        factory: databaseFactoryFfi,
        databasePath: path,
      );
      addTearDown(() async {
        await upgraded.close();
        await databaseFactoryFfi.deleteDatabase(path);
        await directory.delete();
      });
      final value = (await KitchenRepository(
        database: upgraded,
      ).listRecipes()).single;
      expect(value.id, id);
      expect(value.name, dish.name);
      expect(value.materials.single.amount, 2);
      expect(await (await upgraded.database).getVersion(), 13);
    },
  );
  test(
    'failed sync keeps local data and retry sends edits made during a request',
    () async {
      final db = await openTestAppDatabase();
      addTearDown(db.close);
      final repo = KitchenRepository(database: db);
      await repo.saveRecipe(dish);
      final api = SyncFixtureApi(database: db, repository: repo)..fail = true;
      final sync = RecipeCloudSync(repository: repo, api: api);
      expect(await sync.synchronize(), contains('待同步'));
      expect((await repo.listRecipes()).single.name, dish.name);
      expect(await (await db.database).query('recipe_sync_queue'), isNotEmpty);
      api.fail = false;
      api.editWhileSending = true;
      await sync.synchronize();
      expect(api.sent, ['我的菜', '同步期间的新编辑']);
      expect(await (await db.database).query('recipe_sync_queue'), isEmpty);
    },
  );
  test(
    'anonymous identity persists locally and private rows are scoped to owner',
    () async {
      final db = await openTestAppDatabase();
      addTearDown(db.close);
      final api = MobileApi(database: db), identity = await api.identity();
      expect(identity['token'].length, 43);
      expect(
        (await MobileApi(database: db).identity())['ownerId'],
        identity['ownerId'],
      );
      final repo = KitchenRepository(database: db);
      final id = await repo.saveRecipe(dish);
      final sql = await db.database;
      expect(
        (await sql.query(
          'recipe',
          where: 'id = ?',
          whereArgs: [id],
        )).single['owner_id'],
        identity['ownerId'],
      );
      expect(await sql.query('recipe_sync_queue'), hasLength(1));
      await api.saveSetting('mobile_identity_v1', {
        'ownerId': 'other-owner',
        'token': 'other',
      });
      expect(await repo.listRecipes(), isEmpty);
      await api.saveSetting('mobile_identity_v1', identity);
      await repo.deleteRecipe(id);
      expect((await sql.query('recipe_sync_queue')).single['deleted'], 1);
    },
  );
  test(
    'public removal preserves the edited personal copy and its sync intent',
    () async {
      final db = await openTestAppDatabase();
      addTearDown(db.close);
      final repo = KitchenRepository(database: db);
      final item = <String, dynamic>{
        ...dish.toMap(),
        'publicId': 'fixture-public',
        'revision': 1,
      };
      await repo.applyPublicRecipes([item]);
      final public = (await repo.listRecipes()).single;
      expect(public.sourceType, 'public');
      final own = Recipe.fromMap({
        ...public.toMap(),
        'name': '我的调整',
      }, id: public.id);
      await repo.saveRecipe(own);
      await repo.applyPublicRecipes([]);
      expect((await repo.listRecipes()).single.name, '我的调整');
      expect((await (await db.database).query('recipe_sync_queue')).length, 1);
    },
  );
  test(
    'weather uses real response, persists forecast provenance, and falls back only to cache',
    () async {
      final db = await openTestAppDatabase();
      addTearDown(db.close);
      final api = FixtureApi(database: db);
      api.values['weather_city'] = {'id': 'fixture', 'name': '成都'};
      api.response = {
        'icon': '☀️',
        'status': '晴',
        'currentTemperature': 20,
        'minTemperature': 15,
        'maxTemperature': 25,
        'region': '成都',
        'date': DateKeyCodec.encode(DateTime.now()),
        'fetchedAt': DateTime.now().toUtc().toIso8601String(),
        'source': '和风天气',
        'isSimulated': false,
      };
      final service = QWeatherService(api: api);
      expect((await service.getCurrentWeather()).isSimulated, isFalse);
      final rows = await (await db.database).query('weather_records');
      expect(rows.single['data_source'], 'qweather:current+forecast-range');
      api.fail = true;
      expect((await service.getCurrentWeather()).cached, isTrue);
      api.values.remove('weather_cache_fixture');
      await expectLater(service.getCurrentWeather(), throwsStateError);
    },
  );
  test('weather refuses to write stale dates as today', () async {
    final db = await openTestAppDatabase();
    addTearDown(db.close);
    final api = FixtureApi(database: db);
    api.values['weather_city'] = {'id': 'fixture', 'name': '成都'};
    api.response = {
      'icon': '☀️',
      'status': '晴',
      'currentTemperature': 20,
      'minTemperature': 15,
      'maxTemperature': 25,
      'region': '成都',
      'date': '2000-01-01',
      'fetchedAt': DateTime.now().toUtc().toIso8601String(),
      'source': '和风天气',
      'isSimulated': false,
    };
    await QWeatherService(api: api).getCurrentWeather();
    expect(await (await db.database).query('weather_records'), isEmpty);
  });
}
