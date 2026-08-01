import 'package:flutter_test/flutter_test.dart';
import 'package:lifeatlas/features/calendar/domain/models/calendar_record.dart';
import 'package:lifeatlas/features/wardrobe/domain/models/clothing_item.dart';
import 'package:lifeatlas/features/wardrobe/domain/models/daily_outfit_record.dart';
import 'package:lifeatlas/features/wardrobe/domain/models/outfit_set.dart';
import 'package:lifeatlas/features/weather/domain/models/weather_record.dart';

void main() {
  group('database model mapping', () {
    test('weather record round-trips through a map', () {
      final record = WeatherRecord(
        id: 1,
        date: DateTime.utc(2026, 7, 26),
        region: '上海',
        weatherType: '晴',
        currentTemperature: 28,
        minTemperature: 24,
        maxTemperature: 32,
        recordedAt: DateTime.utc(2026, 7, 26, 22),
        dataSource: 'test',
      );

      final restored = WeatherRecord.fromMap(record.toMap());

      expect(restored.id, 1);
      expect(restored.region, '上海');
      expect(restored.minTemperature, 24);
      expect(restored.recordedAt, DateTime.utc(2026, 7, 26, 22));
    });

    test('calendar record preserves its type and image paths', () {
      final record = CalendarRecord(
        id: 2,
        date: DateTime.utc(2026, 7, 26),
        type: CalendarRecordType.image,
        textContent: '今日记录',
        imagePaths: const ['images/one.jpg', 'images/two.jpg'],
        createdAt: DateTime.utc(2026, 7, 26, 12),
      );

      final restored = CalendarRecord.fromMap(record.toMap());

      expect(restored.type, CalendarRecordType.image);
      expect(restored.imagePaths, ['images/one.jpg', 'images/two.jpg']);
      expect(restored.textContent, '今日记录');
    });

    test(
      'clothing item preserves tags, measurements and soft-delete state',
      () {
        final createdAt = DateTime.utc(2026, 7, 26);
        final item = ClothingItem(
          id: 3,
          name: '亚麻衬衫',
          imagePath: 'images/shirt.jpg',
          brand: 'LifeAtlas',
          category: '上衣',
          seasonTags: const ['春', '夏'],
          shoulderWidth: 44,
          chestCircumference: 102,
          purchasePrice: 399,
          isDeleted: true,
          wearCount: 5,
          minWornTemperature: 18,
          maxWornTemperature: 29,
          createdAt: createdAt,
          updatedAt: createdAt,
        );

        final restored = ClothingItem.fromMap(item.toMap());

        expect(restored.seasonTags, ['春', '夏']);
        expect(restored.shoulderWidth, 44);
        expect(restored.isDeleted, isTrue);
        expect(restored.wearCount, 5);
      },
    );

    test('outfit set and daily outfit keep relation identifiers', () {
      final timestamp = DateTime.utc(2026, 7, 26);
      final outfitSet = OutfitSet(
        id: 4,
        name: '夏日通勤',
        seasonTags: const ['夏'],
        clothingItemIds: const [1, 2],
        createdAt: timestamp,
        updatedAt: timestamp,
      );
      final dailyOutfit = DailyOutfitRecord(
        id: 5,
        date: timestamp,
        clothingItemIds: const [1, 2],
        recordedAt: timestamp,
        weatherType: '晴',
        minTemperature: 24,
        maxTemperature: 32,
      );

      final restoredSet = OutfitSet.fromMap(
        outfitSet.toMap(),
        clothingItemIds: outfitSet.clothingItemIds,
      );
      final restoredDailyOutfit = DailyOutfitRecord.fromMap(
        dailyOutfit.toMap(),
        clothingItemIds: dailyOutfit.clothingItemIds,
      );

      expect(restoredSet.clothingItemIds, [1, 2]);
      expect(restoredSet.seasonTags, ['夏']);
      expect(restoredDailyOutfit.clothingItemIds, [1, 2]);
      expect(restoredDailyOutfit.maxTemperature, 32);
    });
  });
}
