import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeatlas/features/wardrobe/data/wardrobe_repository.dart';
import 'package:lifeatlas/features/wardrobe/domain/models/clothing_catalog.dart';
import 'package:lifeatlas/features/wardrobe/domain/models/clothing_item.dart';
import 'package:lifeatlas/features/wardrobe/domain/models/daily_outfit_record.dart';
import 'package:lifeatlas/features/wardrobe/domain/models/outfit_set.dart';
import 'package:lifeatlas/features/wardrobe/domain/models/wardrobe_filter.dart';
import 'package:lifeatlas/features/wardrobe/presentation/outfit_page.dart';
import 'package:lifeatlas/features/wardrobe/presentation/wardrobe_keys.dart';

class DateRepository extends WardrobeRepository {
  bool fail = false;
  final records = <DateTime, DailyOutfitRecord>{};
  final saved = <DateTime>[];
  (double?, double?)? confirmed;
  @override
  Future<List<ClothingItem>> listClothing({
    WardrobeFilter filter = const WardrobeFilter(),
  }) async => [
    ClothingItem(
      id: 1,
      name: '长裤',
      imagePath: 'missing.jpg',
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    ),
  ];
  @override
  Future<List<OutfitSet>> listOutfitSets({String? seasonTag}) async => [];
  @override
  Future<List<ClothingCategory>> listCategories({
    bool includeFemaleCategories = false,
  }) async => [];
  @override
  Future<List<ClothingBrand>> listBrands() async => [];
  @override
  Future<DailyOutfitRecord?> getDailyOutfit(DateTime date) async =>
      records[date];
  @override
  Future<void> replaceDailyOutfit({
    required DateTime date,
    required Iterable<int> clothingItemIds,
    DateTime? recordedAt,
    double? confirmedMinimum,
    double? confirmedMaximum,
  }) async {
    if (fail) throw StateError('disk unavailable');
    saved.add(date);
    confirmed = (confirmedMinimum, confirmedMaximum);
    records[date] = DailyOutfitRecord(
      date: date,
      recordedAt: DateTime.now(),
      clothingItemIds: clothingItemIds.toList(),
    );
  }
}

Future<void> pickDate(WidgetTester tester, DateTime date) async {
  await tester.tap(find.byKey(const ValueKey('outfit-record-date')));
  await tester.pumpAndSettle();
  await tester.tap(find.byIcon(Icons.edit_outlined));
  await tester.pumpAndSettle();
  await tester.enterText(
    find.byType(TextField).last,
    '${date.month}/${date.day}/${date.year}',
  );
  await tester.tap(find.text('OK'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'default today, past record loading, dirty switch cancel, retry and midnight date stability',
    (tester) async {
      final repo = DateRepository();
      var now = DateTime(2026, 11, 5, 23, 59);
      final yesterday = DateTime(2026, 11, 4);
      repo.records[yesterday] = DailyOutfitRecord(
        date: yesterday,
        recordedAt: yesterday,
        clothingItemIds: [1],
      );
      final callbacks = <DateTime>[];
      await tester.pumpWidget(
        MaterialApp(
          home: OutfitPage(
            repository: repo,
            now: () => now,
            onDailyOutfitSaved: (date) async {
              callbacks.add(date);
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(WardrobeKeys.startRecording));
      await tester.pumpAndSettle();
      expect(find.text('2026-11-05'), findsOneWidget);
      await tester.tap(find.byKey(WardrobeKeys.clothingSelection(1)));
      await tester.pumpAndSettle();
      await pickDate(tester, yesterday);
      expect(find.text('有未保存的选择'), findsOneWidget);
      await tester.tap(find.widgetWithText(TextButton, '取消').last);
      await tester.pumpAndSettle();
      expect(find.text('2026-11-05'), findsOneWidget);
      await pickDate(tester, yesterday);
      await tester.tap(find.text('放弃并切换'));
      await tester.pumpAndSettle();
      expect(find.text('2026-11-04'), findsOneWidget);
      expect(
        tester
            .widget<Checkbox>(find.byKey(WardrobeKeys.clothingSelection(1)))
            .value,
        isTrue,
      );
      repo.fail = true;
      await tester.tap(find.byKey(WardrobeKeys.confirmRecording));
      await tester.pumpAndSettle();
      expect(find.text('2026-11-04'), findsOneWidget);
      expect(find.text('穿搭记录保存失败，请稍后重试'), findsOneWidget);
      repo.fail = false;
      now = DateTime(2026, 11, 6);
      await tester.tap(find.byKey(WardrobeKeys.confirmRecording));
      await tester.pumpAndSettle();
      expect(repo.saved.single, yesterday);
      expect(callbacks.single, yesterday);
      await tester.tap(find.byKey(WardrobeKeys.startRecording));
      await tester.pumpAndSettle();
      expect(find.text('2026-11-06'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'old weather review is staged, validated and committed with the selected date',
    (tester) async {
      final repo = DateRepository();
      final day = DateTime(2026, 11, 5);
      repo.records[day] = DailyOutfitRecord(
        date: day,
        recordedAt: day,
        clothingItemIds: [1],
        minTemperature: 22,
        maxTemperature: 30,
        weatherStatus: 'pending',
      );
      await tester.pumpWidget(
        MaterialApp(
          home: OutfitPage(repository: repo, now: () => day),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(WardrobeKeys.startRecording));
      await tester.pumpAndSettle();
      await tester.tap(find.text('旧温度待确认'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('outfit-weather-min')),
        '11.7',
      );
      await tester.enterText(
        find.byKey(const ValueKey('outfit-weather-max')),
        '10',
      );
      await tester.tap(find.text('确认'));
      await tester.pumpAndSettle();
      expect(find.text('最高温不得低于最低温'), findsOneWidget);
      await tester.enterText(
        find.byKey(const ValueKey('outfit-weather-max')),
        '20.1',
      );
      await tester.tap(find.text('确认'));
      await tester.pumpAndSettle();
      expect(repo.saved, isEmpty);
      expect(find.text('温度已确认（待保存）'), findsOneWidget);
      await tester.tap(find.byKey(WardrobeKeys.confirmRecording));
      await tester.pumpAndSettle();
      expect(repo.confirmed, (11.7, 20.1));
      expect(repo.saved, [day]);
      expect(tester.takeException(), isNull);
    },
  );
}
