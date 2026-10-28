import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeatlas/features/wardrobe/data/clothing_image_parameter_service.dart';
import 'package:lifeatlas/features/wardrobe/data/wardrobe_repository.dart';
import 'package:lifeatlas/features/wardrobe/data/wardrobe_image_service.dart';
import 'package:lifeatlas/features/wardrobe/domain/models/clothing_catalog.dart';
import 'package:lifeatlas/features/wardrobe/domain/models/clothing_image_parameters.dart';
import 'package:lifeatlas/features/wardrobe/domain/models/clothing_item.dart';
import 'package:lifeatlas/features/wardrobe/domain/models/clothing_parameter.dart';
import 'package:lifeatlas/features/wardrobe/domain/models/outfit_set.dart';
import 'package:lifeatlas/features/wardrobe/domain/models/wardrobe_filter.dart';
import 'package:lifeatlas/features/wardrobe/presentation/clothing_save_error.dart';
import 'package:lifeatlas/features/wardrobe/presentation/outfit_page_content.dart';
import 'package:lifeatlas/features/wardrobe/presentation/pages/clothing_detail_page.dart';
import 'package:lifeatlas/features/wardrobe/presentation/pages/clothing_form_page.dart';
import 'package:lifeatlas/features/wardrobe/presentation/wardrobe_keys.dart';
import 'package:lifeatlas/features/wardrobe/presentation/widgets/clothing_card.dart';
import 'package:lifeatlas/features/wardrobe/presentation/widgets/clothing_grid.dart';
import 'package:lifeatlas/features/wardrobe/presentation/widgets/wardrobe_filter_bar.dart';

void main() {
  test('default categories expose only relevant measurement fields', () {
    Set<String> keys(String category) => ClothingParameterCatalog.forCategory(
      category,
    ).map((definition) => definition.key).toSet();
    final top = keys('上衣');
    final coat = keys('羽绒外套');
    final trousers = keys('长裤');
    final hat = keys('帽子');
    final glasses = keys('眼镜');

    expect(top, containsAll(['clothing_length', 'chest_circumference']));
    expect(top, isNot(contains('trouser_length')));
    expect(coat, containsAll(['chest_circumference', 'fill_weight']));
    expect(trousers, containsAll(['front_rise', 'back_rise', 'inseam_length']));
    expect(
      trousers,
      containsAll(['waist_circumference_min', 'waist_circumference_max']),
    );
    expect(trousers, isNot(contains('shoulder_width')));
    for (final removedKey in [
      'elastic_waist_min',
      'elastic_waist_max',
      'suggested_height_min',
      'suggested_height_max',
      'suggested_weight_min',
      'suggested_weight_max',
    ]) {
      expect(trousers, isNot(contains(removedKey)));
    }
    expect(hat, containsAll(['accessory_height', 'crown_depth']));
    for (final removedKey in [
      'hood_height',
      'hood_depth',
      'slit_length',
      'collar_height',
      'front_neck_drop',
      'back_neck_drop',
    ]) {
      expect(coat, isNot(contains(removedKey)));
    }
    expect(glasses, containsAll(['frame_width', 'temple_length']));

    for (final category in [
      '外套',
      '上衣',
      '长裤',
      '短裤',
      '家居服',
      '鞋',
      '包',
      '围巾',
      '项链',
      '内衣',
      '裙装',
      '连衣裙',
    ]) {
      final labels = ClothingParameterCatalog.forCategory(
        category,
      ).map((definition) => definition.label);
      expect(labels, isNot(contains('帽高')));
      expect(labels, isNot(contains('帽深')));
      expect(labels, isNot(contains('开衩长')));
      expect(labels, isNot(contains('领高')));
      expect(labels, isNot(contains('前领深')));
      expect(labels, isNot(contains('后领深')));
    }
    final hatLabels = ClothingParameterCatalog.forCategory(
      '帽子',
    ).map((definition) => definition.label);
    expect(hatLabels, containsAll(['帽高', '帽深']));
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
        parameterValues: const {
          'front_rise': 30,
          'waist_circumference_min': 70,
          'waist_circumference_max': 76,
        },
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
      find.byKey(WardrobeKeys.clothingCategorySelector),
      280,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(WardrobeKeys.clothingCategorySelector));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(WardrobeKeys.category('长裤')));
    await tester.pumpAndSettle();
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
    final minimumWaist = tester.widget<TextFormField>(
      find.byKey(WardrobeKeys.clothingWaistMinField),
    );
    final maximumWaist = tester.widget<TextFormField>(
      find.byKey(WardrobeKeys.clothingWaistMaxField),
    );
    expect(minimumWaist.controller?.text, '70');
    expect(maximumWaist.controller?.text, '76');
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
      waistCircumference: 72,
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

    final minimumWaist = tester.widget<TextFormField>(
      find.byKey(WardrobeKeys.clothingWaistMinField),
    );
    final maximumWaist = tester.widget<TextFormField>(
      find.byKey(WardrobeKeys.clothingWaistMaxField),
    );
    expect(minimumWaist.controller?.text, '72');
    expect(maximumWaist.controller?.text, '72');
    await tester.enterText(
      find.byKey(WardrobeKeys.clothingWaistMinField),
      '70',
    );
    await tester.enterText(find.byKey(WardrobeKeys.clothingWaistMaxField), '');

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
    expect(submitted?.waistCircumference, isNull);
    expect(
      submitted?.parameterValues['waist_circumference_min']?.numberValue,
      70,
    );
    expect(
      submitted?.parameterValues.containsKey('waist_circumference_max'),
      isFalse,
    );
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

    expect(find.byKey(WardrobeKeys.season('春')), findsNothing);
    await tester.tap(find.byKey(WardrobeKeys.clothingSeasonSelector));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(WardrobeKeys.season('春')));
    await tester.tap(find.byKey(WardrobeKeys.season('夏')));
    await tester.tap(find.byKey(WardrobeKeys.season('秋')));
    await tester.tap(find.byKey(WardrobeKeys.season('冬')));
    await tester.pumpAndSettle();
    expect(find.text('一件衣服最多选择三个季节'), findsOneWidget);
    await tester.tap(find.byKey(WardrobeKeys.clothingSeasonConfirm));
    await tester.pumpAndSettle();
    expect(find.byKey(WardrobeKeys.season('春')), findsNothing);
    expect(find.text('春、夏、秋'), findsOneWidget);

    expect(find.byKey(WardrobeKeys.category('上衣')), findsNothing);
    await tester.scrollUntilVisible(
      find.byKey(WardrobeKeys.clothingCategorySelector),
      280,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(WardrobeKeys.clothingCategorySelector));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(WardrobeKeys.category('上衣')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(WardrobeKeys.clothingCategorySelector));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(WardrobeKeys.category('长裤')));
    await tester.pumpAndSettle();
    expect(find.byKey(WardrobeKeys.category('长裤')), findsNothing);
    expect(find.text('长裤'), findsOneWidget);

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

  testWidgets('clothing detail displays waist as one range', (tester) async {
    final now = DateTime.utc(2026, 8, 25);
    await tester.pumpWidget(
      MaterialApp(
        home: ClothingDetailPage(
          item: ClothingItem(
            name: '范围上衣',
            imagePath: 'missing/top.jpg',
            category: '上衣',
            parameterValues: const {
              'waist_circumference_min': ClothingParameterValue(
                key: 'waist_circumference_min',
                numberValue: 68,
                unit: 'cm',
              ),
              'waist_circumference_max': ClothingParameterValue(
                key: 'waist_circumference_max',
                numberValue: 74,
                unit: 'cm',
              ),
            },
            createdAt: now,
            updatedAt: now,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('68 – 74 cm'), findsOneWidget);
    expect(find.text('腰围最小值'), findsNothing);
    expect(find.text('腰围最大值'), findsNothing);
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
      find.byKey(WardrobeKeys.clothingCategorySelector),
      280,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(WardrobeKeys.clothingCategorySelector));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(WardrobeKeys.category('长裤')));
    await tester.pumpAndSettle();
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

  testWidgets(
    'season and category selectors do not overlap on a narrow screen',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(280, 700);
      tester.platformDispatcher.textScaleFactorTestValue = 1.4;
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

      await tester.pumpWidget(
        MaterialApp(
          home: ClothingFormPage(
            imageService: _FakeImageService(const []),
            categories: const ['外套', '上衣'],
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('季节：'), findsOneWidget);
      expect(find.text('请选择季节（最多三个）'), findsOneWidget);
      expect(find.text('品类：'), findsOneWidget);
      expect(find.text('请选择品类'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('wardrobe clothing grid always uses three compact columns', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 700);
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    ClothingItem? tappedItem;
    final now = DateTime.utc(2026, 8, 25);
    final items = List.generate(
      6,
      (index) => ClothingItem(
        id: index + 1,
        name: '名称非常长需要省略的测试衣服 ${index + 1}',
        imagePath: 'missing/$index.jpg',
        seasonTags: const ['春', '秋'],
        category: '上衣',
        createdAt: now,
        updatedAt: now,
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(12),
            child: ClothingGrid(
              items: items,
              isRecording: false,
              selectedItemIds: const {},
              onSelectionChanged: (_, _) {},
              onItemTap: (item) => tappedItem = item,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final grid = tester.widget<GridView>(find.byKey(WardrobeKeys.clothingGrid));
    final delegate =
        grid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;
    expect(delegate.crossAxisCount, 3);
    expect(find.byType(ClothingCard), findsNWidgets(6));
    expect(tester.takeException(), isNull);

    await tester.tap(find.byKey(WardrobeKeys.clothingCard(1)));
    await tester.pump();
    expect(tappedItem?.id, 1);
  });

  test('clothing save errors expose specific safe reasons', () {
    expect(clothingSaveErrorMessage(ArgumentError('衣服名称不能为空。')), '衣服名称不能为空');
    expect(
      clothingSaveErrorMessage(const FormatException('购买价格不是数字')),
      '数据格式错误：购买价格不是数字',
    );
    expect(
      clothingSaveErrorMessage(const FileSystemException('disk full')),
      '本地存储失败，请检查存储空间后重试',
    );
    expect(
      clothingSaveErrorMessage(const SocketException('offline')),
      '网络连接失败，请检查网络后重试',
    );
    expect(clothingSaveErrorMessage(Exception()), '保存失败，请稍后重试');
  });

  testWidgets('clothing persistence failure is shown with its actual reason', (
    tester,
  ) async {
    _useTallViewport(tester);
    await tester.pumpWidget(
      MaterialApp(
        home: OutfitPage(
          repository: _FailingWardrobeRepository(ArgumentError('所选品类不存在。')),
          imageService: _FakeImageService(const ['missing/display.jpg']),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(WardrobeKeys.addClothing));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(WardrobeKeys.clothingImagePicker));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(WardrobeKeys.clothingNameField), '测试衣服');
    await tester.tap(find.byKey(WardrobeKeys.clothingSubmit));
    await tester.pumpAndSettle();

    expect(find.text('所选品类不存在'), findsOneWidget);
    expect(find.text('衣服保存失败，请稍后重试'), findsNothing);
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

class _FailingWardrobeRepository extends WardrobeRepository {
  _FailingWardrobeRepository(this.error);

  final Object error;

  @override
  Future<List<ClothingItem>> listClothing({
    WardrobeFilter filter = const WardrobeFilter(),
  }) async => const [];

  @override
  Future<List<OutfitSet>> listOutfitSets({String? seasonTag}) async => const [];

  @override
  Future<List<ClothingCategory>> listCategories({
    bool includeFemaleCategories = false,
  }) async => [
    ClothingCategory(
      id: 1,
      name: '上衣',
      isDefault: true,
      createdAt: DateTime.utc(2026, 8, 25),
    ),
  ];

  @override
  Future<List<ClothingBrand>> listBrands() async => const [];

  @override
  Future<int> createClothing(ClothingItem item) async => throw error;
}
