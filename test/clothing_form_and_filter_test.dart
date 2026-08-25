import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeatlas/features/wardrobe/data/clothing_image_parameter_service.dart';
import 'package:lifeatlas/features/wardrobe/data/wardrobe_image_service.dart';
import 'package:lifeatlas/features/wardrobe/domain/models/clothing_image_parameters.dart';
import 'package:lifeatlas/features/wardrobe/domain/models/clothing_item.dart';
import 'package:lifeatlas/features/wardrobe/domain/models/clothing_parameter.dart';
import 'package:lifeatlas/features/wardrobe/presentation/pages/clothing_form_page.dart';
import 'package:lifeatlas/features/wardrobe/presentation/wardrobe_keys.dart';
import 'package:lifeatlas/features/wardrobe/presentation/widgets/wardrobe_filter_bar.dart';

void main() {
  test('default categories expose only relevant measurement fields', () {
    Set<String> keys(String category) => ClothingParameterCatalog.forCategory(
      category,
    ).map((definition) => definition.key).toSet();
    final top = keys('上衣');
    final coat = keys('羽绒外套');
    final trousers = keys('长裤');
    final glasses = keys('眼镜');

    expect(top, containsAll(['clothing_length', 'chest_circumference']));
    expect(top, isNot(contains('trouser_length')));
    expect(coat, containsAll(['chest_circumference', 'fill_weight']));
    expect(trousers, containsAll(['front_rise', 'back_rise', 'inseam_length']));
    expect(trousers, isNot(contains('shoulder_width')));
    expect(glasses, containsAll(['frame_width', 'temple_length']));
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

  testWidgets('display image and AI measurement image stay independent', (
    tester,
  ) async {
    _useTallViewport(tester);
    final imageService = _FakeImageService([
      'missing/display.jpg',
      'missing/measurements.jpg',
    ]);
    final parameterService = _FakeImageParameterService(
      ClothingImageParameters(
        name: '识别长裤',
        category: '长裤',
        brand: 'Atlas',
        seasonTags: const ['春', '秋'],
        material: '棉',
        clothingLength: 60,
        trouserLength: 98,
        parameterValues: const {'front_rise': 30},
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
    expect(nameField.controller?.text, isEmpty);
    expect(parameterService.analyzedPaths, isEmpty);

    await tester.scrollUntilVisible(
      find.byKey(WardrobeKeys.category('长裤')),
      280,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(WardrobeKeys.category('长裤')));
    await tester.scrollUntilVisible(
      find.byKey(WardrobeKeys.clothingSizeToggle),
      280,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(WardrobeKeys.clothingSizeToggle));
    await tester.pumpAndSettle();
    expect(find.byKey(WardrobeKeys.clothingSizeContent), findsOneWidget);

    await tester.scrollUntilVisible(
      find.byKey(WardrobeKeys.clothingMeasurementImagePicker),
      280,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(WardrobeKeys.clothingMeasurementImagePicker));
    await tester.pumpAndSettle();
    expect(parameterService.analyzedPaths, isEmpty);

    await tester.tap(find.byKey(WardrobeKeys.clothingMeasurementImageAnalyze));
    await tester.pumpAndSettle();

    expect(nameField.controller?.text, isEmpty);
    expect(parameterService.analyzedPaths, ['missing/measurements.jpg']);
    expect(find.text('已识别尺寸，请核对后保存'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byKey(WardrobeKeys.clothingTrouserLengthField),
      280,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.byKey(WardrobeKeys.clothingTrouserLengthField), findsOneWidget);
    expect(find.byKey(WardrobeKeys.clothingLengthField), findsNothing);
    await tester.scrollUntilVisible(
      find.text('前裆长（cm）'),
      280,
      scrollable: find.byType(Scrollable).first,
    );
    final frontRise = tester.widget<TextFormField>(
      find.widgetWithText(TextFormField, '前裆长（cm）'),
    );
    expect(frontRise.controller?.text, '30');
  });

  testWidgets('hidden measurements are cleared from the submitted item', (
    tester,
  ) async {
    _useTallViewport(tester);
    ClothingItem? submitted;
    final now = DateTime.utc(2026, 8, 21);
    final initialItem = ClothingItem(
      id: 1,
      name: '测试上衣',
      imagePath: 'missing/top.jpg',
      category: '上衣',
      material: '棉',
      clothingLength: 70,
      trouserLength: 100,
      parameterValues: const {
        'sku': ClothingParameterValue(key: 'sku', textValue: 'OLD-SKU'),
        'fit': ClothingParameterValue(key: 'fit', textValue: '合身'),
      },
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
                    imageService: _FakeImageService(const []),
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

    expect(find.byKey(WardrobeKeys.clothingLengthField), findsNothing);
    await tester.scrollUntilVisible(
      find.byKey(WardrobeKeys.clothingSizeToggle),
      280,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(WardrobeKeys.clothingSizeToggle));
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
    expect(submitted?.material, '棉');
    expect(submitted?.parameterValues['sku']?.textValue, 'OLD-SKU');
    expect(submitted?.parameterValues['fit']?.textValue, '合身');
  });

  testWidgets('category is single-select and size values survive collapsing', (
    tester,
  ) async {
    _useTallViewport(tester);
    await tester.pumpWidget(
      MaterialApp(
        home: ClothingFormPage(
          imageService: _FakeImageService(const []),
          categories: const ['外套', '上衣', '长裤'],
        ),
      ),
    );

    await tester.scrollUntilVisible(
      find.byKey(WardrobeKeys.category('上衣')),
      280,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(WardrobeKeys.category('上衣')));
    await tester.tap(find.byKey(WardrobeKeys.category('长裤')));
    await tester.pumpAndSettle();

    ChoiceChip chip(String category) =>
        tester.widget<ChoiceChip>(find.byKey(WardrobeKeys.category(category)));
    expect(chip('上衣').selected, isFalse);
    expect(chip('长裤').selected, isTrue);

    await tester.scrollUntilVisible(
      find.byKey(WardrobeKeys.clothingSizeToggle),
      280,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(WardrobeKeys.clothingSizeToggle));
    await tester.pumpAndSettle();
    expect(find.text('商品信息'), findsNothing);
    expect(find.text('材质'), findsNothing);
    expect(find.text('版型'), findsNothing);
    await tester.scrollUntilVisible(
      find.byKey(WardrobeKeys.clothingTrouserLengthField),
      280,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.enterText(
      find.byKey(WardrobeKeys.clothingTrouserLengthField),
      '101',
    );

    await tester.scrollUntilVisible(
      find.byKey(WardrobeKeys.clothingSizeToggle),
      -280,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(WardrobeKeys.clothingSizeToggle));
    await tester.pumpAndSettle();
    expect(find.byKey(WardrobeKeys.clothingTrouserLengthField), findsNothing);

    await tester.tap(find.byKey(WardrobeKeys.clothingSizeToggle));
    await tester.pumpAndSettle();
    final field = tester.widget<TextFormField>(
      find.descendant(
        of: find.byKey(WardrobeKeys.clothingTrouserLengthField),
        matching: find.byType(TextFormField),
      ),
    );
    expect(field.controller?.text, '101');
  });

  testWidgets('unconfigured AI leaves manually entered dimensions intact', (
    tester,
  ) async {
    _useTallViewport(tester);
    await tester.pumpWidget(
      MaterialApp(
        home: ClothingFormPage(
          imageService: _FakeImageService(const ['missing/size.jpg']),
          categories: const ['长裤'],
        ),
      ),
    );

    await tester.scrollUntilVisible(
      find.byKey(WardrobeKeys.category('长裤')),
      280,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(WardrobeKeys.category('长裤')));
    await tester.scrollUntilVisible(
      find.byKey(WardrobeKeys.clothingSizeToggle),
      280,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(WardrobeKeys.clothingSizeToggle));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(WardrobeKeys.clothingTrouserLengthField),
      280,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.enterText(
      find.byKey(WardrobeKeys.clothingTrouserLengthField),
      '99',
    );
    await tester.ensureVisible(
      find.byKey(WardrobeKeys.clothingMeasurementImagePicker),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(WardrobeKeys.clothingMeasurementImagePicker));
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.byKey(WardrobeKeys.clothingMeasurementImageAnalyze),
    );
    await tester.tap(find.byKey(WardrobeKeys.clothingMeasurementImageAnalyze));
    await tester.pumpAndSettle();

    expect(find.text('请先配置 AI 接口，可继续手动填写尺寸'), findsOneWidget);
    final field = tester.widget<TextFormField>(
      find.descendant(
        of: find.byKey(WardrobeKeys.clothingTrouserLengthField),
        matching: find.byType(TextFormField),
      ),
    );
    expect(field.controller?.text, '99');
  });
}

void _useTallViewport(WidgetTester tester) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(800, 1200);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
}

class _FakeImageService implements WardrobeImageService {
  _FakeImageService(this.paths);

  final List<String?> paths;
  var _nextPath = 0;

  @override
  Future<String?> pickSingleFromGallery() async {
    if (_nextPath >= paths.length) {
      return null;
    }
    return paths[_nextPath++];
  }

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
