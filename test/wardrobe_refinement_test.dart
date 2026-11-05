import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeatlas/core/database/app_database.dart';
import 'package:lifeatlas/core/database/outfit_weather_integrity.dart';
import 'package:lifeatlas/core/network/mobile_api.dart';
import 'package:lifeatlas/features/home/data/weather_service.dart';
import 'package:lifeatlas/features/wardrobe/data/wardrobe_repository.dart';
import 'package:lifeatlas/features/wardrobe/domain/models/clothing_image_parameters.dart';
import 'package:lifeatlas/features/wardrobe/domain/models/clothing_item.dart';
import 'package:lifeatlas/features/wardrobe/domain/models/clothing_parameter.dart';
import 'package:lifeatlas/features/wardrobe/presentation/pages/clothing_detail_page.dart';

import 'support/test_database.dart';

ClothingItem garment({
  Map<String, ClothingParameterValue> parameters = const {},
}) => ClothingItem(
  name: '测试长裤',
  imagePath: 'missing.jpg',
  category: '长裤',
  parameterValues: parameters,
  createdAt: DateTime(2026, 8, 1),
  updatedAt: DateTime(2026, 8, 1),
);

class RealWeatherFixture extends MobileApi {
  RealWeatherFixture(AppDatabase db) : super(database: db);
  String city = 'a';
  bool fail = false;
  String? switchDuringRequest;
  String date = '2026-11-05';
  double minimum = 11.7, maximum = 20.1;
  @override
  Future<Object?> setting(String key) async => key == 'weather_city'
      ? {'id': city, 'tz': 'Asia/Shanghai'}
      : super.setting(key);
  @override
  Future<Map<String, dynamic>> call(
    String action, [
    Map<String, Object?> data = const {},
  ]) async {
    if (fail) throw StateError('offline');
    if (switchDuringRequest != null) city = switchDuringRequest!;
    return {
      'icon': '☀️',
      'status': '晴',
      'currentTemperature': 18,
      'minTemperature': minimum,
      'maxTemperature': maximum,
      'region': '城市',
      'date': date,
      'fetchedAt': '2026-11-05T04:00:00Z',
      'source': '和风天气',
      'isSimulated': false,
    };
  }
}

void main() {
  late AppDatabase db;
  late WardrobeRepository repo;
  setUp(() async {
    db = await openTestAppDatabase();
    repo = WardrobeRepository(database: db);
  });
  tearDown(() => db.close());

  test(
    'real weather replaces same-city snapshot and shrinks contaminated aggregate',
    () async {
      final id = await repo.createClothing(garment());
      final day = DateTime(2026, 11, 5);
      await repo.replaceDailyOutfit(date: day, clothingItemIds: [id]);
      // Reproduce old actual -> mock expansion without depending on the removed callback.
      final sql = await db.database;
      await sql.update('clothing_items', {
        'min_worn_temperature': 11.7,
        'max_worn_temperature': 30,
      });
      await sql.update('daily_outfit_records', {
        'min_temperature': 22,
        'max_temperature': 30,
        'weather_status': 'verified',
        'weather_source': 'qweather:current+forecast-range',
        'weather_city_id': 'a',
      });
      final api = RealWeatherFixture(db);
      await QWeatherService(
        api: api,
        clock: () => DateTime.utc(2026, 11, 5, 4),
      ).getCurrentWeather();
      expect((await repo.getClothing(id))!.minWornTemperature, 11.7);
      expect((await repo.getClothing(id))!.maxWornTemperature, 20.1);
      final row = (await sql.query('daily_outfit_records')).single;
      expect(row['max_temperature'], 20.1);
      expect(row['weather_city_id'], 'a');
      expect(row['weather_fetched_at'], '2026-11-05T04:00:00Z');
      api.maximum = 19;
      await QWeatherService(
        api: api,
        clock: () => DateTime.utc(2026, 11, 5, 4),
      ).getCurrentWeather(forceRefresh: true);
      expect((await repo.getClothing(id))!.maxWornTemperature, 19);
    },
  );

  test(
    'genuine 30-degree historical day survives correction; removing it recomputes',
    () async {
      final id = await repo.createClothing(garment());
      for (final day in [DateTime(2026, 8, 1), DateTime(2026, 8, 2)]) {
        await repo.replaceDailyOutfit(date: day, clothingItemIds: [id]);
        await repo.applyTemperatureForDate(
          date: day,
          minTemperature: 11.7,
          maxTemperature: 30,
        );
      }
      await repo.applyTemperatureForDate(
        date: DateTime(2026, 8, 2),
        minTemperature: 11.7,
        maxTemperature: 20.1,
      );
      expect((await repo.getClothing(id))!.maxWornTemperature, 30);
      await repo.deleteDailyOutfit(DateTime(2026, 8, 1));
      expect((await repo.getClothing(id))!.maxWornTemperature, 20.1);
      expect((await repo.getClothing(id))!.wearCount, 1);
    },
  );

  test(
    'past record without weather stays empty; manual correction is atomic and idempotent',
    () async {
      final id = await repo.createClothing(garment());
      final day = DateTime(2026, 8, 1);
      await repo.replaceDailyOutfit(date: day, clothingItemIds: [id]);
      expect((await repo.getDailyOutfit(day))!.maxTemperature, isNull);
      await expectLater(
        repo.replaceDailyOutfit(
          date: day,
          clothingItemIds: [id],
          confirmedMinimum: 20,
          confirmedMaximum: 10,
        ),
        throwsArgumentError,
      );
      expect((await repo.getDailyOutfit(day))!.maxTemperature, isNull);
      for (var i = 0; i < 2; i++) {
        await repo.replaceDailyOutfit(
          date: day,
          clothingItemIds: [id],
          confirmedMinimum: 11.7,
          confirmedMaximum: 20.1,
        );
      }
      expect((await repo.getClothing(id))!.wearCount, 1);
      expect((await repo.getClothing(id))!.maxWornTemperature, 20.1);
      final sql = await db.database;
      expect(
        (await sql.query('daily_outfit_records')).single['weather_source'],
        'user-confirmed',
      );
      await expectLater(
        repo.replaceDailyOutfit(
          date: DateTime.now().add(const Duration(days: 1)),
          clothingItemIds: [id],
        ),
        throwsArgumentError,
      );
    },
  );

  test(
    'legacy migration retains uncertain values without guessing and can be reviewed',
    () async {
      final id = await repo.createClothing(garment());
      final day = DateTime(2026, 8, 1);
      await repo.replaceDailyOutfit(date: day, clothingItemIds: [id]);
      final sql = await db.database;
      await sql.update('daily_outfit_records', {
        'min_temperature': 22,
        'max_temperature': 30,
      });
      await sql.update('clothing_items', {
        'max_worn_temperature': 30,
        'min_worn_temperature': 11.7,
      });
      for (final table in ['weather_records', 'daily_outfit_records']) {
        for (final column in ['weather_city_id', 'weather_zone']) {
          await sql.execute('ALTER TABLE $table DROP COLUMN $column');
        }
      }
      for (final column in [
        'weather_status',
        'weather_source',
        'weather_fetched_at',
      ]) {
        await sql.execute(
          'ALTER TABLE daily_outfit_records DROP COLUMN $column',
        );
      }
      await upgradeOutfitWeatherToV14(sql);
      expect((await repo.getDailyOutfit(day))!.weatherStatus, 'pending');
      expect((await repo.getDailyOutfit(day))!.maxTemperature, 30);
      expect((await repo.getClothing(id))!.maxWornTemperature, isNull);
      expect((await repo.getClothing(id))!.wearCount, 1);
      expect(await repo.syncPendingTemperatureMemory(), 0);
      await repo.replaceDailyOutfit(
        date: day,
        clothingItemIds: [id],
        confirmedMinimum: 11.7,
        confirmedMaximum: 20.1,
      );
      await upgradeOutfitWeatherToV14(
        sql,
      ); // Idempotence preserves confirmed data.
      expect((await repo.getDailyOutfit(day))!.weatherStatus, 'verified');
      expect((await repo.getClothing(id))!.maxWornTemperature, 20.1);
    },
  );

  test(
    'city switching and failed refresh do not overwrite a confirmed snapshot',
    () async {
      final id = await repo.createClothing(garment());
      final day = DateTime(2026, 11, 5);
      await repo.replaceDailyOutfit(date: day, clothingItemIds: [id]);
      final api = RealWeatherFixture(db);
      final service = QWeatherService(
        api: api,
        clock: () => DateTime.utc(2026, 11, 5, 4),
      );
      await service.getCurrentWeather();
      api.city = 'b';
      api.maximum = 35;
      await service.getCurrentWeather();
      await repo.replaceDailyOutfit(date: day, clothingItemIds: [id]);
      expect((await repo.getDailyOutfit(day))!.maxTemperature, 20.1);
      api.fail = true;
      expect((await service.getCurrentWeather()).cached, isTrue);
      expect((await repo.getClothing(id))!.maxWornTemperature, 20.1);
      api.city = 'c';
      await expectLater(service.getCurrentWeather(), throwsStateError);
      expect((await repo.getDailyOutfit(day))!.maxTemperature, 20.1);
    },
  );

  test(
    'stale dates and a city changed during a request are not persisted',
    () async {
      final api = RealWeatherFixture(db)..date = '2026-11-04';
      final service = QWeatherService(
        api: api,
        clock: () => DateTime.utc(2026, 11, 5, 4),
      );
      await expectLater(service.getCurrentWeather(), throwsFormatException);
      api.date = '2026-11-05';
      api.switchDuringRequest = 'b';
      await expectLater(service.getCurrentWeather(), throwsStateError);
      expect(await (await db.database).query('weather_records'), isEmpty);
    },
  );

  test(
    'untraceable legacy weather requires explicit confirmation even when today refreshes',
    () async {
      final id = await repo.createClothing(garment());
      final day = DateTime(2026, 11, 5);
      await repo.replaceDailyOutfit(date: day, clothingItemIds: [id]);
      final sql = await db.database;
      await sql.update('daily_outfit_records', {
        'min_temperature': 22,
        'max_temperature': 30,
        'weather_status': 'pending',
      });
      final api = RealWeatherFixture(db);
      final service = QWeatherService(
        api: api,
        clock: () => DateTime.utc(2026, 11, 5, 4),
      );
      await service.getCurrentWeather();
      await repo.replaceDailyOutfit(date: day, clothingItemIds: [id]);
      expect((await repo.getDailyOutfit(day))!.weatherStatus, 'pending');
      expect((await repo.getDailyOutfit(day))!.maxTemperature, 30);
      expect((await repo.getClothing(id))!.maxWornTemperature, isNull);
      await repo.replaceDailyOutfit(
        date: day,
        clothingItemIds: [id],
        confirmedMinimum: 11.7,
        confirmedMaximum: 20.1,
      );
      api.maximum = 35;
      await service.getCurrentWeather();
      expect((await repo.getDailyOutfit(day))!.maxTemperature, 20.1);
    },
  );

  test(
    'a city changed during a refresh cannot fall back to the previous city cache',
    () async {
      final api = RealWeatherFixture(db);
      final service = QWeatherService(
        api: api,
        clock: () => DateTime.utc(2026, 11, 5, 4),
      );
      await service.getCurrentWeather();
      api.switchDuringRequest = 'b';
      await expectLater(
        service.getCurrentWeather(forceRefresh: true),
        throwsStateError,
      );
      expect(
        (await (await db.database).query(
          'weather_records',
        )).single['weather_city_id'],
        'a',
      );
    },
  );

  test(
    'range parameters round-trip and reject reversed, zero or nonfinite ranges',
    () async {
      Map<String, ClothingParameterValue> range(double min, double max) => {
        'hip_circumference_min': ClothingParameterValue(
          key: 'hip_circumference_min',
          numberValue: min,
        ),
        'hip_circumference_max': ClothingParameterValue(
          key: 'hip_circumference_max',
          numberValue: max,
        ),
      };
      final id = await repo.createClothing(garment(parameters: range(96, 104)));
      expect(
        (await repo.getClothing(
          id,
        ))!.parameterValues['hip_circumference_max']!.numberValue,
        104,
      );
      for (final values in [
        range(104, 96),
        range(0, 100),
        range(double.nan, 100),
      ]) {
        await expectLater(
          repo.createClothing(garment(parameters: values)),
          throwsArgumentError,
        );
      }
      expect(await repo.listClothing(), hasLength(1));
      final parsed = ClothingImageParameters.fromJson({
        'parameters': {
          'hip_circumference': '96–104 cm',
          'thigh_circumference_min': 50,
          'thigh_circumference_max': 58,
        },
      });
      expect(parsed.parameterValues['hip_circumference_max'], 104);
      expect(parsed.parameterValues['thigh_circumference_min'], 50);
    },
  );

  testWidgets(
    'detail merges dimensions and keeps parenthesized label intact at large font',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          builder: (c, child) => MediaQuery(
            data: MediaQuery.of(
              c,
            ).copyWith(textScaler: const TextScaler.linear(1.4)),
            child: child!,
          ),
          home: ClothingDetailPage(
            item: garment(
              parameters: {
                'hip_circumference_min': const ClothingParameterValue(
                  key: 'hip_circumference_min',
                  numberValue: 96,
                ),
                'hip_circumference_max': const ClothingParameterValue(
                  key: 'hip_circumference_max',
                  numberValue: 104,
                ),
                'trouser_length': const ClothingParameterValue(
                  key: 'trouser_length',
                  numberValue: 100,
                ),
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('尺寸'), findsOneWidget);
      expect(find.text('裤装尺寸'), findsNothing);
      await tester.scrollUntilVisible(find.text('裤长\n（外长）'), 200);
      expect(find.text('裤长\n（外长）'), findsOneWidget);
      expect(find.text('96 – 104 cm'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
