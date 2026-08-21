import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeatlas/features/wardrobe/data/clothing_image_parameter_service.dart';
import 'package:lifeatlas/features/wardrobe/data/wardrobe_image_service.dart';
import 'package:lifeatlas/features/wardrobe/domain/models/clothing_image_parameters.dart';
import 'package:lifeatlas/features/wardrobe/domain/models/clothing_item.dart';
import 'package:lifeatlas/features/wardrobe/domain/models/clothing_parameter_profile.dart';
import 'package:lifeatlas/features/wardrobe/presentation/pages/clothing_form_page.dart';
import 'package:lifeatlas/features/wardrobe/presentation/wardrobe_keys.dart';
import 'package:lifeatlas/features/wardrobe/presentation/widgets/wardrobe_filter_bar.dart';

void main() {
  test('default categories expose only relevant measurement fields', () {
    final top = ClothingParameterProfile.forCategory('上衣');
    final trousers = ClothingParameterProfile.forCategory('长裤');
    final accessory = ClothingParameterProfile.forCategory('饰品');
    final custom = ClothingParameterProfile.forCategory('自定义品类');

    expect(top.includes(ClothingMeasurementField.clothingLength), isTrue);
    expect(top.includes(ClothingMeasurementField.trouserLength), isFalse);
    expect(trousers.includes(ClothingMeasurementField.trouserLength), isTrue);
    expect(trousers.includes(ClothingMeasurementField.shoulderWidth), isFalse);
    expect(accessory.fields, isEmpty);
    expect(custom.fields, ClothingParameterProfile.all.fields);
  });

  testWidgets('filter conditions are collapsed behind one button', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WardrobeFilterBar(
            seasons: const ['春', '夏', '秋', '冬'],
            categories: const ['上衣'],
            brands: const ['Atlas'],
            selectedSeason: '春',
            selectedCategory: null,
            selectedBrand: null,
            onSeasonChanged: (_) {},
            onCategoryChanged: (_) {},
            onBrandChanged: (_) {},
            onClear: () {},
          ),
        ),
      ),
    );

    expect(find.text('筛选（1）'), findsOneWidget);
    expect(find.byKey(WardrobeKeys.seasonFilter), findsNothing);

    await tester.tap(find.byKey(WardrobeKeys.filterToggle));
    await tester.pumpAndSettle();

    expect(find.byKey(WardrobeKeys.seasonFilter), findsOneWidget);
    expect(find.byKey(WardrobeKeys.categoryFilter), findsOneWidget);
    expect(find.byKey(WardrobeKeys.brandFilter), findsOneWidget);
  });

  testWidgets('image analysis fills blanks and changes visible parameters', (
    tester,
  ) async {
    final imageService = _FakeImageService('missing/recognized.jpg');
    final parameterService = _FakeImageParameterService(
      ClothingImageParameters(
        name: '识别长裤',
        category: '长裤',
        brand: 'Atlas',
        seasonTags: const ['春', '秋'],
        material: '棉',
        clothingLength: 60,
        trouserLength: 98,
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: ClothingFormPage(
          imageService: imageService,
          imageParameterService: parameterService,
          categories: const ['上衣', '长裤'],
        ),
      ),
    );

    await tester.tap(find.byKey(WardrobeKeys.clothingImagePicker));
    await tester.pumpAndSettle();

    final nameField = tester.widget<TextFormField>(
      find.byKey(WardrobeKeys.clothingNameField),
    );
    expect(nameField.controller?.text, '识别长裤');
    expect(parameterService.analyzedPaths, ['missing/recognized.jpg']);
    expect(find.text('已读取图片参数，请核对后保存'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byKey(WardrobeKeys.clothingTrouserLengthField),
      280,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.byKey(WardrobeKeys.clothingTrouserLengthField), findsOneWidget);
    expect(find.byKey(WardrobeKeys.clothingLengthField), findsNothing);
  });

  testWidgets('hidden measurements are cleared from the submitted item', (
    tester,
  ) async {
    ClothingItem? submitted;
    final now = DateTime.utc(2026, 8, 21);
    final initialItem = ClothingItem(
      id: 1,
      name: '测试上衣',
      imagePath: 'missing/top.jpg',
      category: '上衣',
      clothingLength: 70,
      trouserLength: 100,
      createdAt: now,
      updatedAt: now,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => FilledButton(
            onPressed: () async {
              submitted = await Navigator.of(context).push<ClothingItem>(
                MaterialPageRoute(
                  builder: (context) => ClothingFormPage(
                    imageService: _FakeImageService(null),
                    initialItem: initialItem,
                    categories: const ['上衣', '长裤'],
                  ),
                ),
              );
            },
            child: const Text('打开表单'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('打开表单'));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.byKey(WardrobeKeys.clothingLengthField),
      280,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.byKey(WardrobeKeys.clothingLengthField), findsOneWidget);
    expect(find.byKey(WardrobeKeys.clothingTrouserLengthField), findsNothing);

    await tester.tap(find.byKey(WardrobeKeys.clothingSubmit));
    await tester.pumpAndSettle();

    expect(submitted?.clothingLength, 70);
    expect(submitted?.trouserLength, isNull);
  });
}

class _FakeImageService implements WardrobeImageService {
  _FakeImageService(this.path);

  final String? path;

  @override
  Future<String?> pickSingleFromGallery() async => path;

  @override
  Future<List<String>> retrieveLostData() async => const [];
}

class _FakeImageParameterService implements ClothingImageParameterService {
  _FakeImageParameterService(this.result);

  final ClothingImageParameters result;
  final List<String> analyzedPaths = [];

  @override
  bool get isConfigured => true;

  @override
  Future<ClothingImageParameters> analyze(String imagePath) async {
    analyzedPaths.add(imagePath);
    return result;
  }
}
