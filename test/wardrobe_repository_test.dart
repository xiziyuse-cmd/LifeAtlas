import 'package:flutter_test/flutter_test.dart';
import 'package:lifeatlas/core/database/app_database.dart';
import 'package:lifeatlas/features/wardrobe/data/wardrobe_repository.dart';
import 'package:lifeatlas/features/wardrobe/domain/models/clothing_item.dart';
import 'package:lifeatlas/features/wardrobe/domain/models/clothing_parameter.dart';
import 'package:lifeatlas/features/wardrobe/domain/models/outfit_set.dart';
import 'package:lifeatlas/features/wardrobe/domain/models/preorder_analysis.dart';
import 'package:lifeatlas/features/wardrobe/domain/models/preorder_item.dart';
import 'package:lifeatlas/features/wardrobe/domain/models/wardrobe_filter.dart';

import 'support/test_database.dart';

void main() {
  group('WardrobeRepository', () {
    late WardrobeRepository repository;
    late AppDatabase appDatabase;
    late DateTime timestamp;

    setUp(() async {
      appDatabase = await openTestAppDatabase();
      addTearDown(appDatabase.close);
      repository = WardrobeRepository(database: appDatabase);
      timestamp = DateTime.utc(2026, 8, 16, 8);
    });

    test('catalogs are seeded and custom names are normalized', () async {
      final categories = await repository.listCategories();
      expect(categories, hasLength(20));
      expect(categories.map((item) => item.name), isNot(contains('连体裤')));
      expect(categories.map((item) => item.name), isNot(contains('饰品')));
      final first = await repository.createBrand('  Example   Brand  ');
      final duplicate = await repository.createBrand('example brand');

      expect(duplicate.id, first.id);
      expect(duplicate.name, 'Example   Brand');
    });

    test('clothing CRUD and combined filters use catalog ids', () async {
      final category = await repository.createCategory('功能外套');
      final brand = await repository.createBrand('Atlas');
      final matchingId = await repository.createClothing(
        _clothing(
          name: '风衣',
          seasons: const ['春', '秋', '春'],
          categoryId: category.id,
          brandId: brand.id,
        ),
      );
      await repository.createClothing(
        _clothing(name: '夏装', seasons: const ['夏']),
      );

      final result = await repository.listClothing(
        filter: WardrobeFilter(
          seasonTags: const {'秋'},
          categoryIds: {category.id},
          brandIds: {brand.id},
        ),
      );
      expect(result.map((item) => item.id), [matchingId]);
      expect(result.single.seasonTags, ['春', '秋']);

      await repository.softDeleteClothing(matchingId);
      expect(await repository.getClothing(matchingId), isNull);
      expect(
        await repository.getClothing(matchingId, includeDeleted: true),
        isNotNull,
      );
    });

    test(
      'dynamic category parameters persist and empty values are omitted',
      () async {
        final id = await repository.createClothing(
          _clothing(name: '工装裤').copyWith(
            category: '长裤',
            trouserLength: 102,
            parameterValues: const {
              'trouser_length': ClothingParameterValue(
                key: 'trouser_length',
                numberValue: 102,
                unit: 'cm',
              ),
              'front_rise': ClothingParameterValue(
                key: 'front_rise',
                numberValue: 31,
                unit: 'cm',
              ),
              'back_rise': ClothingParameterValue(
                key: 'back_rise',
                numberValue: 40,
                unit: 'cm',
              ),
              'fit': ClothingParameterValue(key: 'fit', textValue: '宽松'),
              'sku': ClothingParameterValue(key: 'sku'),
            },
          ),
        );

        final item = await repository.getClothing(id);
        expect(item!.parameterValues['front_rise']?.numberValue, 31);
        expect(item.parameterValues['back_rise']?.numberValue, 40);
        expect(item.parameterValues['fit']?.textValue, '宽松');
        expect(item.parameterValues, isNot(contains('sku')));
      },
    );

    test('outfit set keeps member order', () async {
      final first = await repository.createClothing(_clothing(name: '上衣'));
      final second = await repository.createClothing(_clothing(name: '长裤'));
      final third = await repository.createClothing(_clothing(name: '鞋'));
      final setId = await repository.createOutfitSet(
        OutfitSet(
          name: '通勤',
          seasonTags: const ['春'],
          clothingItemIds: [second, first, third],
          createdAt: timestamp,
          updatedAt: timestamp,
        ),
      );

      expect((await repository.getOutfitSet(setId))!.clothingItemIds, [
        second,
        first,
        third,
      ]);
    });

    test('daily replace is idempotent and temperature only expands', () async {
      final first = await repository.createClothing(_clothing(name: '上衣'));
      final second = await repository.createClothing(_clothing(name: '长裤'));
      final third = await repository.createClothing(_clothing(name: '外套'));
      final day = DateTime(2026, 8, 16);

      await repository.replaceDailyOutfit(
        date: day,
        clothingItemIds: [first, second],
      );
      await repository.replaceDailyOutfit(
        date: day,
        clothingItemIds: [first, second],
      );
      expect((await repository.getClothing(first))!.wearCount, 1);
      expect((await repository.getClothing(second))!.wearCount, 1);

      await repository.replaceDailyOutfit(
        date: day,
        clothingItemIds: [second, third],
      );
      expect((await repository.getClothing(first))!.wearCount, 0);
      expect((await repository.getClothing(second))!.wearCount, 1);
      expect((await repository.getClothing(third))!.wearCount, 1);

      await repository.applyTemperatureForDate(
        date: day,
        minTemperature: 10,
        maxTemperature: 20,
      );
      await repository.applyTemperatureForDate(
        date: day,
        minTemperature: 12,
        maxTemperature: 19,
      );
      await repository.applyTemperatureForDate(
        date: day,
        minTemperature: 8,
        maxTemperature: 21,
      );
      final remembered = await repository.getClothing(second);
      expect(remembered!.minWornTemperature, 8);
      expect(remembered.maxWornTemperature, 21);

      await repository.deleteDailyOutfit(day);
      expect((await repository.getClothing(second))!.wearCount, 0);
      expect((await repository.getClothing(second))!.minWornTemperature, 8);
    });

    test(
      'pending weather is compensated and recommendation uses strict tiers',
      () async {
        final exact = await repository.createClothing(_clothing(name: '精确'));
        final partial = await repository.createClothing(_clothing(name: '部分'));
        final exactDay = DateTime(2026, 8, 14);
        final partialDay = DateTime(2026, 8, 15);
        await repository.replaceDailyOutfit(
          date: exactDay,
          clothingItemIds: [exact],
        );
        await repository.applyTemperatureForDate(
          date: exactDay,
          minTemperature: 8,
          maxTemperature: 22,
        );
        await repository.replaceDailyOutfit(
          date: partialDay,
          clothingItemIds: [partial],
        );
        final database = await appDatabase.database;
        await database.insert('weather_records', {
          'record_date': '2026-08-15T00:00:00.000',
          'region': '上海',
          'weather_type': '晴',
          'min_temperature': 15,
          'max_temperature': 25,
          'recorded_at': timestamp.toIso8601String(),
        });
        expect(await repository.syncPendingTemperatureMemory(), 1);

        final exactOnly = await repository.recommendForTemperature(
          minTemperature: 10,
          maxTemperature: 20,
        );
        expect(exactOnly.map((entry) => entry.item.id), [exact]);

        final fallback = await repository.recommendForTemperature(
          minTemperature: 23,
          maxTemperature: 27,
        );
        expect(fallback.first.item.id, partial);
        expect(fallback.every((entry) => !entry.isFullMatch), isTrue);
      },
    );

    test(
      'preorder analyses are append-only and purchase hides the item',
      () async {
        final preorderId = await repository.createPreorder(
          PreorderItem(
            imagePath: 'images/wanted.jpg',
            name: '心仪外套',
            createdAt: timestamp,
            updatedAt: timestamp,
          ),
        );
        await repository.appendPreorderAnalysis(
          PreorderAnalysis(
            preorderItemId: preorderId,
            promptVersion: 'v1',
            model: 'test-model',
            resultText: '第一次分析',
            totalTokens: 10,
            analyzedAt: timestamp,
          ),
        );
        await repository.appendPreorderAnalysis(
          PreorderAnalysis(
            preorderItemId: preorderId,
            promptVersion: 'v2',
            model: 'test-model',
            resultText: '第二次分析',
            totalTokens: 12,
            analyzedAt: timestamp.add(const Duration(minutes: 1)),
          ),
        );

        final analyses = await repository.listPreorderAnalyses(preorderId);
        expect(analyses.map((item) => item.resultText), ['第二次分析', '第一次分析']);
        await repository.markPreorderPurchased(preorderId);
        expect(await repository.listPreorders(), isEmpty);
        expect(
          await repository.listPreorders(includePurchased: true),
          hasLength(1),
        );
        expect(await repository.listPreorderAnalyses(preorderId), hasLength(2));
      },
    );
  });
}

ClothingItem _clothing({
  required String name,
  List<String> seasons = const ['春'],
  int? categoryId,
  int? brandId,
}) {
  final now = DateTime.utc(2026, 8, 16);
  return ClothingItem(
    name: name,
    imagePath: 'images/$name.jpg',
    categoryId: categoryId,
    brandId: brandId,
    seasonTags: seasons,
    createdAt: now,
    updatedAt: now,
  );
}
