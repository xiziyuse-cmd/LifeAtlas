import 'package:flutter_test/flutter_test.dart';
import 'package:lifeatlas/core/database/app_database.dart';
import 'package:lifeatlas/features/home/data/weather_service.dart';
import 'package:lifeatlas/features/wardrobe/application/outfit_weather_sync.dart';
import 'package:lifeatlas/features/wardrobe/data/wardrobe_repository.dart';

import 'support/test_database.dart';
import 'wardrobe_refinement_test.dart' show RealWeatherFixture, garment;

void main() {
  late AppDatabase db;
  late WardrobeRepository repo;
  late RealWeatherFixture api;
  late QWeatherService weather;
  late OutfitWeatherSync sync;
  final today = DateTime(2026, 11, 5);
  DateTime clock() => DateTime.utc(2026, 11, 5, 4);
  late int id;
  setUp(() async {
    db = await openTestAppDatabase();
    repo = WardrobeRepository(database: db);
    api = RealWeatherFixture(db);
    await api.saveSetting('weather_city', {'id': 'a', 'tz': 'Asia/Shanghai'});
    weather = QWeatherService(api: api, clock: clock);
    sync = OutfitWeatherSync(repository: repo, weather: weather, clock: clock);
    id = await repo.createClothing(garment());
    await repo.replaceDailyOutfit(date: today, clothingItemIds: [id]);
  });
  tearDown(() => db.close());

  test(
    'saving today applies real min/max, keeps wear counts idempotent',
    () async {
      await sync.sync(today);
      await repo.replaceDailyOutfit(date: today, clothingItemIds: [id]);
      await sync.sync(today);
      final item = (await repo.getClothing(id))!;
      expect(item.minWornTemperature, 11.7);
      expect(item.maxWornTemperature, 20.1);
      expect(item.wearCount, 1);
      expect((await repo.getDailyOutfit(today))!.weatherStatus, 'verified');
    },
  );

  test(
    'explicitly recording today confirms pending snapshot without confirming historical days',
    () async {
      final past = DateTime(2026, 8, 1);
      await repo.replaceDailyOutfit(date: past, clothingItemIds: [id]);
      final sql = await db.database;
      await sql.update('daily_outfit_records', {
        'weather_status': 'pending',
        'min_temperature': 22,
        'max_temperature': 30,
      });
      await weather.getCurrentWeather();
      expect((await repo.getDailyOutfit(today))!.weatherStatus, 'pending');
      await sync.sync(today);
      expect((await repo.getDailyOutfit(today))!.maxTemperature, 20.1);
      expect((await repo.getDailyOutfit(past))!.weatherStatus, 'pending');
      expect((await repo.getDailyOutfit(past))!.maxTemperature, 30);
      expect((await repo.getClothing(id))!.maxWornTemperature, 20.1);
    },
  );

  test(
    'validated same-day cache is applied even if no weather table snapshot exists',
    () async {
      await weather.getCurrentWeather();
      final sql = await db.database;
      await sql.delete('weather_records');
      await sql.update('daily_outfit_records', {
        'weather_status': 'missing',
        'min_temperature': null,
        'max_temperature': null,
      });
      await sql.update('clothing_items', {
        'min_worn_temperature': null,
        'max_worn_temperature': null,
      });
      api.fail = true;
      await sync.sync(today);
      final record = (await repo.getDailyOutfit(today))!;
      expect(record.minTemperature, 11.7);
      expect(record.maxTemperature, 20.1);
      expect((await repo.getClothing(id))!.maxWornTemperature, 20.1);
      final raw = (await sql.query('daily_outfit_records')).single;
      expect(raw['weather_city_id'], 'a');
      expect(raw['weather_fetched_at'], '2026-11-05T04:00:00Z');
    },
  );

  test(
    'missing or expired cache fails without fabricating temperature',
    () async {
      api.fail = true;
      await expectLater(sync.sync(today), throwsStateError);
      expect((await repo.getClothing(id))!.maxWornTemperature, isNull);
      api.fail = false;
      await weather.getCurrentWeather();
      final cache = Map<String, dynamic>.from(
        (await api.setting('weather_cache_a')) as Map,
      )..['date'] = '2026-11-04';
      await api.saveSetting('weather_cache_a', cache);
      await (await db.database).update('daily_outfit_records', {
        'weather_status': 'pending',
        'max_temperature': 30,
      });
      api.fail = true;
      await expectLater(sync.sync(today), throwsStateError);
      expect((await repo.getDailyOutfit(today))!.weatherStatus, 'pending');
    },
  );

  test('manual values and another confirmed city remain intact', () async {
    await repo.replaceDailyOutfit(
      date: today,
      clothingItemIds: [id],
      confirmedMinimum: 5,
      confirmedMaximum: 10,
    );
    await sync.sync(today);
    expect((await repo.getClothing(id))!.maxWornTemperature, 10);
    final sql = await db.database;
    await sql.update('daily_outfit_records', {
      'weather_source': 'qweather:current+forecast-range',
      'weather_city_id': 'other',
    });
    await expectLater(sync.sync(today), throwsStateError);
    expect((await repo.getDailyOutfit(today))!.maxTemperature, 10);
  });

  test(
    'city change rejects late confirmation and transaction leaves data intact',
    () async {
      api.switchDuringRequest = 'b';
      await expectLater(sync.sync(today), throwsStateError);
      expect((await repo.getDailyOutfit(today))!.maxTemperature, isNull);
      await api.saveSetting('weather_city', {'id': 'b', 'tz': 'Asia/Shanghai'});
      await expectLater(
        repo.confirmRecordedWeather(
          date: today,
          cityId: 'a',
          zone: 'Asia/Shanghai',
          minimum: 11.7,
          maximum: 20.1,
          weatherType: '晴',
          fetchedAt: '2026-11-05T04:00:00Z',
        ),
        throwsStateError,
      );
      expect((await repo.getClothing(id))!.maxWornTemperature, isNull);
    },
  );

  test(
    'past dates and cleared records do not request or apply today weather',
    () async {
      api.fail = true;
      await sync.sync(DateTime(2026, 11, 4));
      await repo.deleteDailyOutfit(today);
      await sync.sync(today);
      expect(await (await db.database).query('weather_records'), isEmpty);
      expect((await repo.getClothing(id))!.wearCount, 0);
    },
  );
}
