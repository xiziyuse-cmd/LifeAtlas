import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeatlas/features/wardrobe/domain/models/clothing_item.dart';
import 'package:lifeatlas/features/wardrobe/domain/models/clothing_measurement_display.dart';
import 'package:lifeatlas/features/wardrobe/domain/models/clothing_parameter.dart';
import 'package:lifeatlas/features/wardrobe/domain/models/outfit_set.dart';
import 'package:lifeatlas/features/wardrobe/domain/models/wardrobe_filter.dart';
import 'package:lifeatlas/features/wardrobe/presentation/outfit_page.dart';
import 'package:lifeatlas/features/wardrobe/presentation/pages/clothing_detail_page.dart';
import 'package:lifeatlas/features/wardrobe/presentation/wardrobe_keys.dart';
import 'package:lifeatlas/features/wardrobe/presentation/widgets/clothing_card.dart';
import 'package:lifeatlas/features/wardrobe/presentation/widgets/outfit_set_carousel_card.dart';
import 'package:lifeatlas/features/wardrobe/presentation/widgets/wardrobe_filter_bar.dart';
import 'package:lifeatlas/features/wardrobe/presentation/widgets/wardrobe_tag.dart';

import 'outfit_date_record_test.dart' show DateRepository;

ClothingItem displayItem({
  Map<String, ClothingParameterValue> values = const {},
}) => ClothingItem(
  id: 1,
  name: '日常长裤',
  imagePath: 'missing.jpg',
  seasonTags: ['夏'],
  category: '长裤',
  brand: 'Atlas',
  material: '棉',
  size: 'L',
  trouserLength: 100,
  parameterValues: values,
  createdAt: DateTime(2026, 8, 1),
  updatedAt: DateTime(2026, 8, 1),
);

class FreshDetailRepository extends DateRepository {
  @override
  Future<List<ClothingItem>> listClothing({
    WardrobeFilter filter = const WardrobeFilter(),
  }) async => [displayItem()];
  @override
  Future<ClothingItem?> getClothing(
    int id, {
    bool includeDeleted = false,
  }) async => displayItem().copyWith(
    wearCount: 1,
    minWornTemperature: 11.7,
    maxWornTemperature: 20.1,
  );
}

void main() {
  test(
    'all circumference displays collapse single, one-sided or equal values without changing data',
    () {
      expect(measurementRangeDisplay(null, null), isNull);
      expect(measurementRangeDisplay(84, null), '84 cm');
      expect(measurementRangeDisplay(null, 84), '84 cm');
      expect(measurementRangeDisplay(84, 84.0), '84 cm');
      expect(measurementRangeDisplay(84, 92), '84 – 92 cm');
      expect(measurementRangeDisplay(84.25, 92.75), '84.25 – 92.75 cm');
      for (final base in [
        'waist_circumference',
        'hip_circumference',
        'thigh_circumference',
      ]) {
        final values = {
          '${base}_min': ClothingParameterValue(
            key: '${base}_min',
            numberValue: 84,
          ),
        };
        final item = displayItem(values: values);
        expect(clothingCircumferenceDisplay(item, base), '84 cm');
        expect(item.parameterValues.containsKey('${base}_max'), isFalse);
        expect(
          clothingCircumferenceDisplay(
            displayItem(
              values: {
                base: ClothingParameterValue(key: base, numberValue: 84),
              },
            ),
            base,
          ),
          '84 cm',
        );
      }
    },
  );

  testWidgets(
    'compact and regular clothing cards expose only image and name, selection still works',
    (tester) async {
      for (final compact in [false, true]) {
        bool selected = false;
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 200,
                height: 350,
                child: ClothingCard(
                  item: displayItem(),
                  onTap: () {},
                  compact: compact,
                  isRecording: true,
                  onSelectionChanged: (value) => selected = value,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byType(Text), findsOneWidget);
        expect(find.text('日常长裤'), findsOneWidget);
        for (final extra in ['夏', '长裤', 'Atlas', '棉', 'L']) {
          expect(find.text(extra), findsNothing);
        }
        await tester.tap(find.byKey(WardrobeKeys.clothingSelection(1)));
        await tester.pump();
        expect(selected, isTrue);
        expect(tester.takeException(), isNull);
      }
    },
  );

  testWidgets(
    'set carousel keeps navigation but removes all extra clothing metadata',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OutfitSetCarouselCard(
              outfitSet: OutfitSet(
                id: 1,
                name: '日常套装',
                seasonTags: ['夏'],
                clothingItemIds: [1],
                createdAt: DateTime(2026),
                updatedAt: DateTime(2026),
              ),
              items: [displayItem()],
              onItemTap: (_) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('日常长裤'), findsOneWidget);
      expect(find.text('日常套装'), findsOneWidget);
      expect(find.text('1/1'), findsOneWidget);
      expect(find.textContaining('夏'), findsNothing);
      expect(find.textContaining('Atlas'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'tag kinds stay distinct for identical names with readable light and dark colors',
    (tester) async {
      for (final brightness in Brightness.values) {
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(brightness: brightness),
            home: const Scaffold(
              body: Wrap(
                children: [
                  WardrobeTag(label: '相同名称', kind: WardrobeTagKind.season),
                  WardrobeTag(label: '相同名称', kind: WardrobeTagKind.category),
                  WardrobeTag(label: '相同名称', kind: WardrobeTagKind.brand),
                ],
              ),
            ),
          ),
        );
        final chips = tester.widgetList<Chip>(find.byType(Chip)).toList();
        expect(chips.map((c) => c.backgroundColor).toSet(), hasLength(3));
        for (final chip in chips) {
          final foreground = chip.labelStyle!.color!.computeLuminance();
          final background = chip.backgroundColor!.computeLuminance();
          final ratio = foreground > background
              ? (foreground + .05) / (background + .05)
              : (background + .05) / (foreground + .05);
          expect(ratio, greaterThanOrEqualTo(4.5));
        }
        expect(find.bySemanticsLabel('季节：相同名称'), findsOneWidget);
        expect(find.bySemanticsLabel('种类：相同名称'), findsOneWidget);
        expect(find.bySemanticsLabel('品牌：相同名称'), findsOneWidget);
      }
    },
  );

  testWidgets(
    'filter categories have distinct colors and menu selection remains functional',
    (tester) async {
      String? season;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WardrobeFilterBar(
              seasons: const ['夏'],
              categories: const ['长裤'],
              brands: const ['Atlas'],
              selectedSeason: null,
              selectedCategory: null,
              selectedBrand: null,
              onSeasonChanged: (v) => season = v,
              onCategoryChanged: (_) {},
              onBrandChanged: (_) {},
              onClear: () {},
            ),
          ),
        ),
      );
      await tester.tap(find.byKey(WardrobeKeys.filterToggle));
      await tester.pumpAndSettle();
      final colors = tester
          .widgetList<InputChip>(find.byType(InputChip))
          .map((c) => c.color!.resolve({}))
          .toSet();
      expect(colors, hasLength(3));
      await tester.tap(find.byKey(WardrobeKeys.seasonFilter));
      await tester.pumpAndSettle();
      await tester.tap(find.text('夏'));
      await tester.pumpAndSettle();
      expect(season, '夏');
    },
  );

  testWidgets(
    'detail has collapsed values and full one-line pants label at narrow large text',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          builder: (c, child) => MediaQuery(
            data: MediaQuery.of(
              c,
            ).copyWith(textScaler: const TextScaler.linear(1.8)),
            child: child!,
          ),
          home: ClothingDetailPage(
            item: displayItem(
              values: const {
                'waist_circumference_min': ClothingParameterValue(
                  key: 'waist_circumference_min',
                  numberValue: 84,
                ),
                'waist_circumference_max': ClothingParameterValue(
                  key: 'waist_circumference_max',
                  numberValue: 84.0,
                ),
                'hip_circumference_min': ClothingParameterValue(
                  key: 'hip_circumference_min',
                  numberValue: 96,
                ),
                'thigh_circumference_min': ClothingParameterValue(
                  key: 'thigh_circumference_min',
                  numberValue: 50,
                ),
                'thigh_circumference_max': ClothingParameterValue(
                  key: 'thigh_circumference_max',
                  numberValue: 58,
                ),
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text('裤长(外长)'), 200);
      final text = tester.widget<Text>(find.text('裤长(外长)'));
      expect(text.maxLines, 1);
      expect(text.softWrap, isFalse);
      expect(find.text('84 cm'), findsOneWidget);
      expect(find.text('96 cm'), findsOneWidget);
      expect(find.text('50 – 58 cm'), findsOneWidget);
      expect(find.text('84 – 84 cm'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'opening detail re-reads temperature instead of using an old list object',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(home: OutfitPage(repository: FreshDetailRepository())),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(WardrobeKeys.clothingCard(1)));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text('20.1℃'), 300);
      expect(find.text('11.7℃'), findsOneWidget);
      expect(find.text('20.1℃'), findsOneWidget);
      expect(find.text('尚无已确认温度'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
