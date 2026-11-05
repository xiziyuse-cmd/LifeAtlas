import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeatlas/core/database/app_database.dart';
import 'package:lifeatlas/app/app_controller.dart';
import 'package:lifeatlas/core/settings/app_settings.dart';
import 'package:lifeatlas/core/settings/app_settings_repository.dart';
import 'package:lifeatlas/core/network/mobile_api.dart';
import 'package:lifeatlas/features/home/data/home_repository.dart';
import 'package:lifeatlas/features/home/data/weather_service.dart';
import 'package:lifeatlas/features/home/domain/hourly_weather.dart';
import 'package:lifeatlas/features/home/domain/weather_model.dart';
import 'package:lifeatlas/features/kitchen/data/kitchen_repository.dart';
import 'package:lifeatlas/features/kitchen/domain/kitchen_models.dart';
import 'package:lifeatlas/features/kitchen/domain/shopping_list.dart';
import 'package:lifeatlas/features/kitchen/presentation/export_image_renderer.dart';
import 'package:lifeatlas/features/search/data/search_repository.dart';
import 'package:lifeatlas/features/search/domain/search_document.dart';
import 'package:lifeatlas/features/search/presentation/search_page.dart';
import 'package:lifeatlas/features/search/presentation/search_sources.dart';
import 'package:lifeatlas/features/skincare/data/skincare_ai_service.dart';
import 'package:lifeatlas/features/wardrobe/data/wardrobe_image_service.dart';
import 'package:lifeatlas/features/wardrobe/data/preorder_analysis_service.dart';
import 'package:lifeatlas/features/skincare/data/skincare_repository.dart';
import 'package:lifeatlas/features/skincare/domain/skincare_models.dart';
import 'package:lifeatlas/features/wardrobe/data/wardrobe_repository.dart';
import 'package:lifeatlas/features/wardrobe/domain/models/clothing_item.dart';
import 'package:lifeatlas/features/wardrobe/domain/models/preorder_item.dart';
import 'support/test_database.dart';

Recipe recipe({int? id, String name = '测试香菇鸡肉'}) => Recipe(
  id: id,
  name: name,
  materials: const [
    RecipeMaterial(name: '鸡肉', amount: 100, unit: 'g'),
    RecipeMaterial(name: '香菇'),
  ],
  seasonings: const [RecipeMaterial(name: '盐', amount: 1, unit: 'g')],
  steps: const [RecipeStep(name: '炖煮', content: '小火炖熟。', duration: 20)],
);

SearchDocument help(String id, String title, {String body = '标准操作说明'}) =>
    SearchDocument(
      id: id,
      title: title,
      body: body,
      category: SearchCategory.kitchen,
      kind: SearchKind.help,
      target: 'shopping',
      question: true,
      keywords: const ['购物清单', '清单导出'],
      source: 'LifeAtlas 使用说明',
      time: '2026-11-05',
    );

class WidgetSearchRepository extends SearchRepository {
  WidgetSearchRepository()
    : super(
        kitchen: KitchenRepository(),
        wardrobe: WardrobeRepository(),
        skincare: SkincareRepository(),
        home: HomeRepository(),
      );
  List<SearchDocument> docs = [help('a', '购物清单怎么导出？'), help('b', '怎样生成购物清单？')];
  List<String> failures = [];
  final pending = <String, Completer<SearchDocument>>{};
  bool failResolve = false;
  int loads = 0;
  @override
  Future<SearchSnapshot> load() async {
    loads++;
    return SearchSnapshot([...docs], [...failures]);
  }

  @override
  Future<SearchDocument> resolve(SearchDocument d) async {
    if (failResolve) throw StateError('deleted');
    if (pending[d.id] case final p?) return p.future;
    return d;
  }
}

class BrokenKitchen extends KitchenRepository {
  @override
  Future<List<Recipe>> listRecipes() async => throw StateError('unavailable');
  @override
  Future<List<InventoryItem>> listInventory() async => [];
}

class SearchSettings implements AppSettingsRepository {
  @override
  Future<AppSettings> load() async => const AppSettings();
  @override
  Future<void> saveThemePreference(AppThemePreference preference) async {}
  @override
  Future<void> saveThemePalette(AppThemePalette palette) async {}
  @override
  Future<void> saveOutfitModuleEnabled(bool enabled) async {}
  @override
  Future<void> saveKitchenModuleEnabled(bool enabled) async {}
  @override
  Future<void> saveSkincareModuleEnabled(bool enabled) async {}
  @override
  Future<void> saveProfileGender(ProfileGender gender) async {}
}

class SearchWeather extends QWeatherService {
  Map<String, dynamic> city = {
    'id': 'new-york',
    'name': '纽约',
    'tz': 'America/New_York',
  };
  bool changeCity = false, fail = false;
  Map<String, dynamic>? requested;
  @override
  Future<Map<String, dynamic>?> selectedCity() async => Map.of(city);
  @override
  Future<HourlyForecast> getHourlyWeather({
    bool forceRefresh = false,
    Map<String, dynamic>? citySnapshot,
  }) async {
    requested = citySnapshot;
    if (fail) throw StateError('network');
    if (changeCity) {
      city = {'id': 'shanghai', 'name': '上海', 'tz': 'Asia/Shanghai'};
    }
    return HourlyForecast.fromJson(
      {
        'cityId': 'new-york',
        'tz': 'America/New_York',
        'fetchedAt': '2026-11-05T00:00:00Z',
        'hours': [
          {
            'time': '2026-11-05T04:00:00Z',
            'icon': '100',
            'status': '纽约今晚',
            'temperature': 12,
          },
          {
            'time': '2026-11-05T14:00:00Z',
            'icon': '101',
            'status': '纽约明早',
            'temperature': 13,
          },
        ],
      },
      cached: true,
      warning: '离线缓存',
    );
  }

  @override
  Future<WeatherModel> getCurrentWeather({
    double? latitude,
    double? longitude,
    bool forceRefresh = false,
    Map<String, dynamic>? citySnapshot,
  }) async {
    requested = citySnapshot;
    if (fail) throw StateError('network');
    return const WeatherModel(
      icon: '100',
      status: '晴',
      currentTemperature: 12,
      minTemperature: 10,
      maxTemperature: 15,
      region: '纽约',
      date: '2026-11-04',
      fetchedAt: '2026-11-05T00:00:00Z',
      source: '和风天气',
      cached: true,
      warning: '离线缓存',
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  group('search source adapters', () {
    late AppDatabase db;
    late KitchenRepository kitchen;
    late WardrobeRepository wardrobe;
    late SkincareRepository skincare;
    late HomeRepository home;
    late SearchRepository repo;
    setUp(() async {
      db = await openTestAppDatabase();
      kitchen = KitchenRepository(database: db);
      wardrobe = WardrobeRepository(database: db);
      skincare = SkincareRepository(database: db);
      home = HomeRepository(database: db);
      repo = SearchRepository(
        kitchen: kitchen,
        wardrobe: wardrobe,
        skincare: skincare,
        home: home,
        clock: () => DateTime(2026, 11, 5, 10),
      );
    });
    tearDown(() async => db.close());

    test(
      'versioned questions, synonyms, category filters and ambiguity',
      () async {
        final docs = await repo.knowledge();
        expect(docs, hasLength(12));
        expect(
          docs.every((d) => d.source.contains('v1') && d.time == '2026-11-05'),
          true,
        );
        final matches = rankSearch(docs, '分享清单');
        expect(matches.first.id, 'help:shopping-export');
        expect(
          rankSearch(docs, '天气', category: SearchCategory.kitchen),
          isEmpty,
        );
        final exact = docs.first;
        expect(exactSearchAnswer(docs, '  ${exact.title}  ')?.id, exact.id);
        expect(exactSearchAnswer([exact, exact], exact.title), isNull);
        expect(exactSearchAnswer(docs, '购物清单'), isNull);
        expect(rankSearch(docs, '火星飞船'), isEmpty);
      },
    );

    test(
      'records search fresh content; deleted recipes cannot resolve or export',
      () async {
        final id = await kitchen.saveRecipe(recipe());
        final first = await repo.load();
        expect(first.failures, isEmpty);
        final found = rankSearch(first.documents, '测试香菇鸡肉').first;
        expect(found.id, 'recipe:$id');
        expect(found.body, contains('小火炖熟'));
        final question = searchQuestions([found], found.title).single;
        expect(question.title, '测试香菇鸡肉怎么做？');
        expect((await repo.resolve(question)).body, contains('鸡肉  100g'));
        await kitchen.saveRecipe(recipe(id: id, name: '改名后的鸡肉'));
        expect((await repo.resolve(found)).title, '改名后的鸡肉');
        expect((await repo.resolve(question)).title, '改名后的鸡肉怎么做？');
        await kitchen.deleteRecipe(id);
        await expectLater(repo.resolve(found), throwsStateError);
        expect(rankSearch((await repo.load()).documents, '改名后的鸡肉'), isEmpty);
      },
    );

    test(
      'shopping template respects portions, prepared ticks, missing amounts and empty state',
      () async {
        final d = SearchRepository.templates.firstWhere(
          (d) => d.id == 'current:shopping',
        );
        expect((await repo.resolve(d)).body, contains('还没有选择菜谱'));
        final id = await kitchen.saveRecipe(recipe());
        final recipes = await kitchen.listRecipes();
        final selected = recipes.where((r) => r.id == id);
        final items = buildShoppingList(selected, servings: {id: 2});
        await kitchen.saveShoppingList(
          ShoppingListState(
            recipeIds: {id},
            servings: {id: 2},
            prepared: {items.first.key},
          ),
        );
        final answer = await repo.resolve(d);
        expect(answer.body, contains('× 2份'));
        expect(answer.body, contains('香菇  用量待补'));
        expect(answer.body, contains('盐  2g'));
        expect(answer.body, isNot(contains('鸡肉  200g')));
        expect(answer.kind, SearchKind.current);
        expect((await kitchen.loadShoppingList()).prepared, {items.first.key});
      },
    );

    test(
      'clothes, preorders, inventory, skincare and old calendar records are searchable; settings are excluded',
      () async {
        final now = DateTime(2026, 11, 5);
        final id = await wardrobe.createClothing(
          ClothingItem(
            name: '黑色搜索外套',
            imagePath: 'test.jpg',
            color: '黑色',
            shoulderWidth: 42,
            createdAt: now,
            updatedAt: now,
            seasonTags: const ['秋'],
          ),
        );
        await wardrobe.createPreorder(
          PreorderItem(
            name: '待购搜索外套',
            imagePath: 'test.jpg',
            createdAt: now,
            updatedAt: now,
          ),
        );
        await kitchen.saveInventory(
          InventoryItem(name: '搜索土豆', amount: 3, unit: '个', updatedAt: now),
        );
        await skincare.saveProduct(
          SkinProduct(
            id: 'search-product',
            name: '搜索保湿产品',
            brand: '测试品牌',
            instructions: '记录用法',
            source: 'https://example.com/product',
          ),
        );
        await home.saveQuickRecord(
          date: DateTime(2020, 1, 2),
          text: '旧日记搜索内容',
          imagePaths: [],
        );
        final api = MobileApi(database: db);
        await api.saveSetting('body_vault_v1', {'data': '身材秘密哨兵'});
        await api.saveSetting('mobile_identity_v1', {
          ...await api.identity(),
          'token': '账号令牌哨兵',
        });
        final snapshot = await repo.load();
        expect(snapshot.failures, isEmpty);
        expect(
          rankSearch(snapshot.documents, '黑色 外套').map((d) => d.id),
          contains('clothing:$id'),
        );
        expect(
          snapshot.documents.firstWhere((d) => d.id == 'clothing:$id').body,
          contains('肩宽：42.0 cm'),
        );
        expect(rankSearch(snapshot.documents, '待购搜索外套'), isNotEmpty);
        expect(rankSearch(snapshot.documents, '搜索土豆'), isNotEmpty);
        expect(rankSearch(snapshot.documents, '测试品牌'), isNotEmpty);
        expect(
          rankSearch(snapshot.documents, '旧日记搜索内容').single.entityId,
          '2020-01-02',
        );
        final serialized = snapshot.documents
            .map((d) => d.searchable)
            .join('\n');
        expect(serialized, isNot(contains('身材秘密哨兵')));
        expect(serialized, isNot(contains('账号令牌哨兵')));
        await wardrobe.softDeleteClothing(id);
        await expectLater(
          repo.resolve(
            snapshot.documents.firstWhere((d) => d.id == 'clothing:$id'),
          ),
          throwsStateError,
        );
      },
    );

    test(
      'one failed adapter does not hide other records or fixed knowledge',
      () async {
        final broken = SearchRepository(
          kitchen: BrokenKitchen(),
          wardrobe: wardrobe,
          skincare: skincare,
          home: home,
        );
        final snapshot = await broken.load();
        expect(snapshot.failures, ['菜谱']);
        expect(snapshot.documents.any((d) => d.kind == SearchKind.help), true);
        expect(snapshot.documents.any((d) => d.id == 'current:shopping'), true);
      },
    );

    test(
      'skin answers use execution snapshot before a new plan and include saved state',
      () async {
        final d = SearchRepository.templates.firstWhere(
          (d) => d.id == 'current:skin-pm',
        );
        expect((await repo.resolve(d)).body, contains('尚未启用'));
        final execution = SkinExecution(
          date: '2026-11-05',
          period: 'pm',
          planId: 'old',
          steps: [
            SkinStep(
              productId: 'old',
              name: '历史产品快照',
              amount: '一泵',
              area: '面部',
            ),
          ],
          states: ['done'],
          updated: '2026-11-05T10:00:00',
        );
        await (await db.database).insert('skincare_executions', {
          'date': execution.date,
          'period': execution.period,
          'data': jsonEncode(execution.toJson()),
        });
        final answer = await repo.resolve(d);
        expect(answer.body, contains('历史产品快照'));
        expect(answer.body, contains('已完成'));
        expect(
          (await repo.load()).documents.any((d) => d.target == 'execution'),
          true,
        );
      },
    );

    test(
      'weather uses city snapshot and city timezone, preserves cache warning and attribution',
      () async {
        final weather = SearchWeather();
        final r = SearchRepository(
          kitchen: kitchen,
          wardrobe: wardrobe,
          skincare: skincare,
          home: home,
          weather: weather,
          clock: () => DateTime.parse('2026-11-05T00:30:00Z'),
        );
        final d = SearchRepository.templates.firstWhere(
          (d) => d.id == 'current:weather-tomorrow',
        );
        final answer = await r.resolve(d);
        expect(weather.requested?['id'], 'new-york');
        expect(answer.body, contains('2026-11-05'));
        expect(answer.body, contains('09:00  纽约明早'));
        expect(answer.body, isNot(contains('纽约今晚')));
        expect(answer.body, contains('使用缓存'));
        expect(answer.sourceUrl, 'https://www.qweather.com/');
        weather.changeCity = true;
        await expectLater(r.resolve(d), throwsStateError);
        weather.fail = true;
        await expectLater(r.resolve(d), throwsStateError);
      },
    );

    test(
      'relative last Saturday is based on the current local calendar date',
      () async {
        await home.saveQuickRecord(
          date: DateTime(2026, 10, 31),
          text: '记录',
          imagePaths: [],
        );
        final d = SearchRepository.templates.firstWhere(
          (d) => d.id == 'current:last-saturday',
        );
        final answer = await repo.resolve(d);
        expect(answer.entityId, '2026-10-31');
        expect(answer.body, contains('没有保存当天的穿搭记录'));
      },
    );
  });

  Widget app(WidgetSearchRepository repo, {double scale = 1}) => MaterialApp(
    builder: (c, child) => MediaQuery(
      data: MediaQuery.of(c).copyWith(textScaler: TextScaler.linear(scale)),
      child: child!,
    ),
    home: GlobalSearchPage(
      repository: repo,
      openSource: (_, _) async {},
      enabled: (_) => false,
      autofocus: false,
    ),
  );

  testWidgets(
    'closed module source requires explicit enable and cancellation preserves state',
    (tester) async {
      final controller = AppController(SearchSettings());
      await controller.initialize();
      final repo = WidgetSearchRepository();
      final sources = SearchSources(
        controller: controller,
        repository: repo,
        kitchenPage: (_) => const SizedBox(),
        wardrobePage: () => const Scaffold(body: Text('原衣柜页面')),
        skinPage: () => const SizedBox(),
        skinAi: SkincareAiService(),
        imageService: DeviceWardrobeImageService(),
        preorderAnalysis: const UnconfiguredPreorderAnalysisService(),
      );
      final doc = SearchDocument(
        id: 'help:wardrobe',
        title: '如何查看衣服',
        category: SearchCategory.wardrobe,
        kind: SearchKind.help,
        target: 'wardrobe',
        question: true,
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (c) => Scaffold(
              body: TextButton(
                onPressed: () => sources.open(c, doc),
                child: const Text('打开原内容'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('打开原内容'));
      await tester.pumpAndSettle();
      expect(find.text('穿搭板块已关闭'), findsOneWidget);
      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();
      expect(controller.outfitModuleEnabled, false);
      expect(find.text('原衣柜页面'), findsNothing);
      await tester.tap(find.text('打开原内容'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('启用并查看'));
      await tester.pumpAndSettle();
      expect(controller.outfitModuleEnabled, true);
      expect(find.text('原衣柜页面'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      controller.dispose();
    },
  );

  testWidgets(
    'suggestions above answers; no ambiguous auto-answer; clear and no results',
    (tester) async {
      final repo = WidgetSearchRepository();
      await tester.pumpWidget(app(repo));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('global-search-input')),
        '购物清单',
      );
      await tester.pump(const Duration(milliseconds: 350));
      await tester.tap(find.text('搜索'));
      await tester.pumpAndSettle();
      expect(find.text('标准操作说明'), findsNothing);
      await tester.tap(find.text('购物清单怎么导出？'));
      await tester.pumpAndSettle();
      expect(find.text('标准操作说明'), findsOneWidget);
      await tester.enterText(
        find.byKey(const ValueKey('global-search-input')),
        '没有匹配的飞船',
      );
      await tester.pump(const Duration(milliseconds: 350));
      expect(find.textContaining('没有找到相关内容'), findsOneWidget);
      await tester.tap(find.byTooltip('清空'));
      await tester.pumpAndSettle();
      expect(find.text('常见问题'), findsOneWidget);
    },
  );

  testWidgets(
    'stale async answers never overwrite a newer query or a cleared session',
    (tester) async {
      final repo = WidgetSearchRepository();
      final pending = Completer<SearchDocument>();
      repo.pending['a'] = pending;
      await tester.pumpWidget(app(repo));
      await tester.pumpAndSettle();
      await tester.tap(find.text('购物清单怎么导出？'));
      await tester.pump();
      await tester.enterText(
        find.byKey(const ValueKey('global-search-input')),
        '不存在',
      );
      await tester.pump(const Duration(milliseconds: 350));
      pending.complete(help('a', '购物清单怎么导出？', body: '过期答案'));
      await tester.pumpAndSettle();
      expect(find.text('过期答案'), findsNothing);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump();
      expect(
        tester
            .widget<TextField>(
              find.byKey(const ValueKey('global-search-input')),
            )
            .controller!
            .text,
        isEmpty,
      );
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'private detail is dismissed on background, retry and failed-source messages are recoverable',
    (tester) async {
      final repo = WidgetSearchRepository();
      repo.failures = ['菜谱'];
      repo.docs.add(
        SearchDocument(
          id: 'recipe:1',
          title: '私人菜谱',
          body: '私人的步骤',
          category: SearchCategory.kitchen,
          kind: SearchKind.record,
          target: 'recipe',
          entityId: '1',
        ),
      );
      await tester.pumpWidget(app(repo));
      await tester.pumpAndSettle();
      expect(find.textContaining('菜谱加载失败'), findsOneWidget);
      repo.failures = [];
      await tester.tap(find.text('重新加载'));
      await tester.pumpAndSettle();
      expect(repo.loads, 2);
      await tester.enterText(
        find.byKey(const ValueKey('global-search-input')),
        '私人菜谱',
      );
      await tester.pump(const Duration(milliseconds: 350));
      expect(find.textContaining('板块已关闭'), findsWidgets);
      await tester.tap(find.widgetWithText(ListTile, '私人菜谱'));
      await tester.pumpAndSettle();
      expect(find.text('答案详情'), findsOneWidget);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pumpAndSettle();
      expect(find.text('答案详情'), findsNothing);
      expect(find.text('私人的步骤'), findsNothing);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'answer export revalidates source and asks before exporting private data',
    (tester) async {
      final repo = WidgetSearchRepository();
      final d = SearchDocument(
        id: 'r',
        title: '我的菜谱',
        body: '个人记录',
        category: SearchCategory.kitchen,
        kind: SearchKind.record,
        target: 'recipe',
      );
      await tester.pumpWidget(
        MaterialApp(
          home: SearchAnswerPage(
            document: d,
            repository: repo,
            openSource: (_, _) async {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('search-export-button')));
      await tester.pumpAndSettle();
      expect(find.text('导出个人记录'), findsOneWidget);
      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();
      repo.failResolve = true;
      await tester.tap(find.byKey(const ValueKey('search-export-button')));
      await tester.pumpAndSettle();
      expect(find.textContaining('内容已变更'), findsOneWidget);
      expect(find.text('导出预览'), findsNothing);
      repo.failResolve = false;
      await tester.tap(find.text('重试'));
      await tester.pumpAndSettle();
      expect(find.text('个人记录'), findsOneWidget);
    },
  );

  testWidgets(
    'narrow-screen search and answer layouts support large text and dark theme',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 740));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final repo = WidgetSearchRepository();
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          builder: (c, child) => MediaQuery(
            data: MediaQuery.of(c).copyWith(textScaler: TextScaler.linear(1.8)),
            child: child!,
          ),
          home: GlobalSearchPage(
            repository: repo,
            openSource: (_, _) async {},
            enabled: (_) => true,
            autofocus: false,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('购物清单怎么导出？'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'real multi-page answer PNG preserves source, date and full document',
    (tester) async {
      final doc = SearchDocument(
        id: 'w',
        title: '逐小时天气与长答案验证',
        category: SearchCategory.calendar,
        kind: SearchKind.current,
        target: 'weather',
        source: '和风天气',
        sourceUrl: 'https://www.qweather.com/',
        time: '2026-11-05T09:00:00+08:00',
        body: List.generate(
          65,
          (i) => '第${i + 1}条完整记录：小时、天气情况和温度，保留来源与日期。',
        ).join('\n'),
      );
      final export = searchAnswerExport(doc);
      expect(export.text, contains('第65条完整记录'));
      expect(export.text, contains('https://www.qweather.com/'));
      expect(export.text, contains(doc.time));
      expect(export.pageNote, contains('和风天气'));
      await tester.runAsync(() async {
        String? family;
        final font = File('C:/Windows/Fonts/msyh.ttc');
        if (await font.exists()) {
          final loader = FontLoader('SearchExportQA')
            ..addFont(
              Future.value((await font.readAsBytes()).buffer.asByteData()),
            );
          await loader.load();
          family = 'SearchExportQA';
        }
        final images = await ExportImageRenderer.render(
          export,
          fontFamily: family,
        );
        expect(images.pages.length, greaterThan(1));
        final directory = Directory('build/search-export-qa');
        await directory.create(recursive: true);
        for (var i = 0; i < images.pages.length; i++) {
          final codec = await ui.instantiateImageCodec(images.pages[i]);
          final frame = await codec.getNextFrame();
          expect(frame.image.width, 800);
          expect(frame.image.height, 1120);
          final pixels = (await frame.image.toByteData(
            format: ui.ImageByteFormat.rawRgba,
          ))!;
          var headerInk = 0;
          for (var y = 26; y < 66; y++) {
            for (var x = 48; x < 752; x++) {
              if (pixels.getUint8((y * 800 + x) * 4) < 180) headerInk++;
            }
          }
          expect(
            headerInk,
            greaterThan(100),
            reason: 'Each page must retain the source/title header',
          );
          frame.image.dispose();
          codec.dispose();
          await File(
            '${directory.path}/answer-${i + 1}.png',
          ).writeAsBytes(images.pages[i]);
        }
      });
    },
  );
}
