import 'package:flutter_test/flutter_test.dart';
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
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
