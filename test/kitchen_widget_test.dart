import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeatlas/features/kitchen/data/kitchen_ai_service.dart';
import 'package:lifeatlas/features/kitchen/data/kitchen_repository.dart';
import 'package:lifeatlas/features/kitchen/data/preset_recipes.dart';
import 'package:lifeatlas/features/kitchen/domain/kitchen_models.dart';
import 'package:lifeatlas/features/kitchen/presentation/kitchen_page.dart';
import 'package:lifeatlas/features/kitchen/presentation/inventory_form_dialog.dart';
import 'package:lifeatlas/features/kitchen/presentation/recipe_form_page.dart';
import 'package:lifeatlas/features/kitchen/presentation/recipe_detail_page.dart';
import 'package:lifeatlas/features/kitchen/presentation/step_form_page.dart';

class _Repository extends KitchenRepository {
  Recipe? saved;
  @override
  Future<List<Recipe>> listRecipes() async => presetRecipes;
  @override
  Future<List<InventoryItem>> listInventory() async => [];
  @override
  Future<List<CookingRecord>> listRecords() async => [];
  @override
  Future<int> saveRecipe(Recipe recipe) async {
    recipe.validate();
    saved = recipe;
    return 10;
  }
}

class _Ai implements KitchenAiService {
  @override
  Future<List<Recipe>> recommend(
    List<InventoryItem> inventory,
    String instruction,
  ) async => presetRecipes;
}

void main() {
  testWidgets(
    'saving steps auto fills foods spices and missing quantities without duplicates',
    (tester) async {
      final repository = _Repository();
      await tester.pumpWidget(
        MaterialApp(
          home: RecipeFormPage(
            repository: repository,
            recipe: const Recipe(name: '自动菜谱'),
          ),
        ),
      );
      final scroll = find.byType(Scrollable).first;
      await tester.scrollUntilVisible(
        find.text('添加步骤'),
        250,
        scrollable: scroll,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('添加步骤'));
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextField, '步骤名称'), '切配');
      await tester.enterText(
        find.widgetWithText(TextField, '步骤描述'),
        '鸡肉100g切块，加盐1勺和胡椒粉，腌制20分钟',
      );
      await tester.scrollUntilVisible(
        find.text('保存步骤'),
        250,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.pumpAndSettle();
      await Scrollable.ensureVisible(
        tester.element(find.text('保存步骤')),
        alignment: .5,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('保存步骤'));
      await tester.pumpAndSettle();
      await tester.drag(find.byType(ListView).first, const Offset(0, 700));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('胡椒粉'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      expect(find.text('鸡肉'), findsOneWidget);
      expect(find.text('100g'), findsOneWidget);
      expect(find.text('盐'), findsOneWidget);
      expect(find.text('1勺'), findsOneWidget);
      expect(find.text('胡椒粉'), findsOneWidget);
      final step = find.text('1. 切配');
      await tester.scrollUntilVisible(
        step,
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(step);
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('保存步骤'),
        200,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.pumpAndSettle();
      await Scrollable.ensureVisible(
        tester.element(find.text('保存步骤')),
        alignment: .5,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('保存步骤'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('保存菜谱'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('保存菜谱'));
      await tester.pumpAndSettle();
      expect(repository.saved!.materials.single.quantity, '100g');
      expect(repository.saved!.seasonings.map((m) => m.name), ['盐', '胡椒粉']);
      expect(repository.saved!.seasonings.last.amount, isNull);
      expect(repository.saved!.seasonings.last.unit, '');
      expect(repository.saved!.steps.single.materials, ['鸡肉']);
      expect(repository.saved!.steps.single.seasonings, ['盐', '胡椒粉']);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('manual name only entry saves without a fabricated amount', (
    tester,
  ) async {
    final repository = _Repository();
    await tester.pumpWidget(
      MaterialApp(
        home: RecipeFormPage(
          repository: repository,
          recipe: const Recipe(
            name: '名称测试',
            steps: [RecipeStep(name: '准备', content: '切片', duration: 5)],
          ),
        ),
      ),
    );
    await tester.scrollUntilVisible(
      find.widgetWithText(TextButton, '新增'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, '新增'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, '名称'), '香菇');
    await tester.tap(find.widgetWithText(FilledButton, '确定'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    await tester.scrollUntilVisible(
      find.text('保存菜谱'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('保存菜谱'));
    await tester.pumpAndSettle();
    expect(repository.saved!.materials.single.amount, isNull);
    expect(repository.saved!.materials.single.quantity, '');
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'editing a blank extracted item does not silently add default units',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: RecipeFormPage(
            repository: _Repository(),
            recipe: const Recipe(
              name: '空白测试',
              seasonings: [RecipeMaterial(name: '胡椒粉')],
            ),
          ),
        ),
      );
      await tester.scrollUntilVisible(
        find.text('胡椒粉'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('胡椒粉'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextField>(find.widgetWithText(TextField, '用量'))
            .controller!
            .text,
        '',
      );
      expect(
        tester
            .widget<TextField>(find.widgetWithText(TextField, '单位'))
            .controller!
            .text,
        '',
      );
      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('renaming a material only updates steps that referenced it', (
    tester,
  ) async {
    final repository = _Repository();
    await tester.pumpWidget(
      MaterialApp(
        home: RecipeFormPage(
          repository: repository,
          recipe: const Recipe(
            name: '关联测试',
            materials: [RecipeMaterial(name: '鸡肉', amount: 100, unit: 'g')],
            steps: [
              RecipeStep(
                name: '备料',
                content: '切块',
                duration: 5,
                materials: ['鸡肉'],
              ),
              RecipeStep(
                name: '等待',
                content: '静置',
                duration: 5,
                parallelWithPrevious: true,
              ),
            ],
          ),
        ),
      ),
    );
    await tester.scrollUntilVisible(
      find.text('鸡肉'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('鸡肉'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, '名称'), '去骨鸡肉');
    await tester.tap(find.widgetWithText(FilledButton, '确定'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('保存菜谱'),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('保存菜谱'));
    await tester.pumpAndSettle();
    expect(repository.saved!.steps.first.materials, ['去骨鸡肉']);
    expect(repository.saved!.steps.last.materials, isEmpty);
    expect(repository.saved!.steps.last.parallelWithPrevious, true);
  });

  const parallelRecipe = Recipe(
    name: '并行菜谱',
    materials: [RecipeMaterial(name: '鸡肉', amount: 100, unit: 'g')],
    steps: [
      RecipeStep(name: '腌制', content: '等待入味', duration: 20),
      RecipeStep(
        name: '切菜',
        content: '切好配菜',
        duration: 22,
        parallelWithPrevious: true,
      ),
      RecipeStep(name: '炒菜', content: '炒熟', duration: 5),
    ],
  );

  testWidgets(
    'first step hides parallel switch and later steps use short label',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: StepFormPage(materials: [], seasonings: []),
        ),
      );
      expect(find.byType(SwitchListTile), findsNothing);
      await tester.pumpWidget(
        const MaterialApp(
          home: StepFormPage(
            key: ValueKey('later-step'),
            canParallel: true,
            materials: [],
            seasonings: [],
          ),
        ),
      );
      expect(find.text('并行'), findsOneWidget);
      expect(
        tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
        false,
      );
      await tester.tap(find.byType(SwitchListTile));
      await tester.pumpAndSettle();
      expect(
        tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
        true,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'step editing updates recipe total and persists parallel choice',
    (tester) async {
      final repository = _Repository();
      await tester.pumpWidget(
        MaterialApp(
          home: RecipeFormPage(repository: repository, recipe: parallelRecipe),
        ),
      );
      final total = find.byKey(const ValueKey('recipe-total-duration'));
      await tester.scrollUntilVisible(
        total,
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('预计制作 27 分钟'), findsOneWidget);
      final second = find.text('2. 切菜');
      await tester.scrollUntilVisible(
        second,
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(second);
      await tester.pumpAndSettle();
      expect(
        tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
        true,
      );
      await tester.tap(find.byType(SwitchListTile));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('保存步骤'),
        250,
        scrollable: find.byType(Scrollable).last,
      );
      await Scrollable.ensureVisible(
        tester.element(find.text('保存步骤')),
        alignment: .5,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('保存步骤'));
      await tester.pumpAndSettle();
      expect(find.text('预计制作 47 分钟'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('保存菜谱'),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('保存菜谱'));
      await tester.pumpAndSettle();
      expect(repository.saved!.totalDuration, 47);
      expect(repository.saved!.steps[1].parallelWithPrevious, false);
    },
  );

  testWidgets(
    'parallel preview labels only the selected step beside its duration',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: RecipeDetailPage(
            repository: _Repository(),
            recipe: parallelRecipe,
          ),
        ),
      );
      await tester.scrollUntilVisible(
        find.text('22分钟'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('预计制作 27 分钟'), findsOneWidget);
      expect(find.text('20分钟'), findsOneWidget);
      expect(find.text('22分钟'), findsOneWidget);
      expect(find.text('并行'), findsOneWidget);
      expect(find.text('并行 · 22 分钟'), findsNothing);
      expect(
        tester.getCenter(find.text('并行')).dx,
        lessThan(tester.getCenter(find.text('22分钟')).dx),
      );
      expect(
        (tester.getCenter(find.text('并行')).dy -
                tester.getCenter(find.text('22分钟')).dy)
            .abs(),
        lessThan(4),
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'removing group leader does not join its successor to an earlier group',
    (tester) async {
      final repository = _Repository();
      await tester.pumpWidget(
        MaterialApp(
          home: RecipeFormPage(
            repository: repository,
            recipe: Recipe(
              name: '删除测试',
              materials: parallelRecipe.materials,
              steps: [
                const RecipeStep(name: '备料', content: '准备', duration: 3),
                ...parallelRecipe.steps,
              ],
            ),
          ),
        ),
      );
      final title = find.text('2. 腌制');
      await tester.scrollUntilVisible(
        title,
        300,
        scrollable: find.byType(Scrollable).first,
      );
      final card = find.ancestor(of: title, matching: find.byType(Card)).first;
      final remove = find.descendant(
        of: card,
        matching: find.byTooltip('移除步骤'),
      );
      await tester.ensureVisible(remove);
      await tester.pumpAndSettle();
      await tester.tap(remove);
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('保存菜谱'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('保存菜谱'));
      await tester.pumpAndSettle();
      expect(repository.saved!.steps.map((s) => s.name), ['备料', '切菜', '炒菜']);
      expect(repository.saved!.steps[1].parallelWithPrevious, false);
      expect(repository.saved!.totalDuration, 30);
    },
  );

  testWidgets('moving a parallel step detaches it without accidental links', (
    tester,
  ) async {
    final repository = _Repository();
    await tester.pumpWidget(
      MaterialApp(
        home: RecipeFormPage(repository: repository, recipe: parallelRecipe),
      ),
    );
    final title = find.text('2. 切菜');
    await tester.scrollUntilVisible(
      title,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    final card = find.ancestor(of: title, matching: find.byType(Card)).first;
    final down = find.descendant(of: card, matching: find.byTooltip('下移'));
    await tester.ensureVisible(down);
    await tester.pumpAndSettle();
    await tester.tap(down);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('保存菜谱'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('保存菜谱'));
    await tester.pumpAndSettle();
    expect(repository.saved!.steps.map((s) => s.name), ['腌制', '炒菜', '切菜']);
    expect(repository.saved!.steps.any((s) => s.parallelWithPrevious), false);
    expect(repository.saved!.totalDuration, 47);
  });

  testWidgets('ingredient buttons set default units and save both types', (
    tester,
  ) async {
    final repository = _Repository();
    await tester.pumpWidget(
      MaterialApp(
        home: RecipeFormPage(
          repository: repository,
          recipe: const Recipe(
            name: '测试菜谱',
            steps: [RecipeStep(name: '拌匀', content: '混合均匀', duration: 2)],
          ),
        ),
      ),
    );
    Future<void> add(
      String type,
      String name,
      String amount,
      String unit,
    ) async {
      final add = find.widgetWithText(TextButton, '新增');
      await tester.ensureVisible(add);
      await tester.tap(add);
      await tester.pumpAndSettle();
      final selector = find.byType(SegmentedButton<bool>);
      expect(selector, findsOneWidget);
      final food = find.descendant(of: selector, matching: find.text('食材'));
      final seasoning = find.descendant(
        of: selector,
        matching: find.text('调料'),
      );
      expect(
        tester.getCenter(food).dx,
        lessThan(tester.getCenter(seasoning).dx),
      );
      expect(
        tester
            .widget<TextField>(find.widgetWithText(TextField, '单位'))
            .controller!
            .text,
        'g',
      );
      await tester.tap(seasoning);
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextField>(find.widgetWithText(TextField, '单位'))
            .controller!
            .text,
        '勺',
      );
      if (type == '食材') {
        await tester.tap(food);
        await tester.pumpAndSettle();
      }
      expect(
        tester
            .widget<TextField>(find.widgetWithText(TextField, '单位'))
            .controller!
            .text,
        unit,
      );
      await tester.enterText(find.widgetWithText(TextField, '名称'), name);
      await tester.enterText(find.widgetWithText(TextField, '用量'), amount);
      await tester.tap(find.widgetWithText(FilledButton, '确定'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
    }

    await add('食材', '胡萝卜', '100', 'g');
    await add('调料', '盐', '1', '勺');
    final save = find.text('保存菜谱');
    await tester.ensureVisible(save);
    await tester.pumpAndSettle();
    await tester.tap(save);
    await tester.pumpAndSettle();
    expect(repository.saved!.materials.single.quantity, '100g');
    expect(repository.saved!.seasonings.single.quantity, '1勺');
    expect(tester.takeException(), isNull);
  });

  testWidgets('editing preserves custom units and duplicate validation', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: RecipeFormPage(
          repository: _Repository(),
          recipe: const Recipe(
            name: '测试菜谱',
            materials: [RecipeMaterial(name: '胡萝卜', amount: 100, unit: 'g')],
            seasonings: [RecipeMaterial(name: '酱油', amount: 1, unit: '小杯')],
          ),
        ),
      ),
    );
    final entry = find.text('酱油');
    await tester.scrollUntilVisible(
      entry,
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await Scrollable.ensureVisible(tester.element(entry), alignment: .5);
    await tester.pumpAndSettle();
    await tester.tap(entry);
    await tester.pumpAndSettle();
    final unit = find.widgetWithText(TextField, '单位');
    expect(tester.widget<TextField>(unit).controller!.text, '小杯');
    final selector = find.byType(SegmentedButton<bool>);
    await tester.tap(find.descendant(of: selector, matching: find.text('食材')));
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(unit).controller!.text, '小杯');
    await tester.enterText(find.widgetWithText(TextField, '名称'), '胡萝卜');
    await tester.tap(find.widgetWithText(FilledButton, '确定'));
    await tester.pumpAndSettle();
    expect(find.text('名称已存在，请编辑已有条目'), findsOneWidget);
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(find.text('酱油'), findsOneWidget);
    expect(find.text('1小杯'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'detail groups ingredients before seasonings without type labels',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: RecipeDetailPage(
            repository: _Repository(),
            recipe: const Recipe(
              name: '测试菜谱',
              materials: [
                RecipeMaterial(
                  name: '胡萝卜',
                  amount: 100,
                  unit: 'g',
                  sort: 3,
                  remark: '不应显示备注',
                ),
                RecipeMaterial(name: '土豆', amount: 200, unit: 'g', sort: 1),
              ],
              seasonings: [
                RecipeMaterial(
                  name: '酱油',
                  amount: 1,
                  unit: '勺',
                  sort: 1,
                  stage: '腌制',
                ),
                RecipeMaterial(name: '盐', amount: 2, unit: '勺', sort: 2),
              ],
            ),
          ),
        ),
      );
      await tester.scrollUntilVisible(
        find.text('盐'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('食材'), findsNothing);
      expect(find.text('调料'), findsNothing);
      expect(find.text('不应显示备注'), findsNothing);
      expect(find.text('腌制'), findsNothing);
      final divider = find.byKey(const ValueKey('recipe-ingredient-divider'));
      expect(divider, findsOneWidget);
      final names = ['土豆', '胡萝卜', '酱油', '盐'];
      for (var i = 0; i < names.length - 1; i++) {
        expect(
          tester.getTopLeft(find.text(names[i])).dy,
          lessThan(tester.getTopLeft(find.text(names[i + 1])).dy),
        );
      }
      expect(
        tester.getTopLeft(divider).dy,
        greaterThan(tester.getTopLeft(find.text('胡萝卜')).dy),
      );
      expect(
        tester.getTopLeft(divider).dy,
        lessThan(tester.getTopLeft(find.text('酱油')).dy),
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('inventory form applies editable food shelf-life default', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: InventoryFormDialog(
            foods: [
              FoodBaseInfo(
                name: '鸡蛋',
                category: '蛋类',
                defaultShelfLife: 30,
                storageType: '冷藏',
              ),
            ],
          ),
        ),
      ),
    );
    await tester.enterText(find.widgetWithText(TextField, '食物名称'), '鸡蛋');
    await tester.testTextInput.receiveAction(TextInputAction.next);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.widgetWithText(TextField, '保质期（天）'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    final shelfField = tester.widget<TextField>(
      find.widgetWithText(TextField, '保质期（天）'),
    );
    expect(shelfField.controller?.text, '30');
    expect(
      find.text(kitchenDate(DateTime.now().add(const Duration(days: 30)))),
      findsOneWidget,
    );
    await tester.enterText(find.widgetWithText(TextField, '保质期（天）'), '21');
    await tester.pump();
    expect(
      find.text(kitchenDate(DateTime.now().add(const Duration(days: 21)))),
      findsOneWidget,
    );
  });
  testWidgets('kitchen has search, three-column cards and two tabs', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(1.4)),
          child: child!,
        ),
        home: Scaffold(
          body: KitchenPage(repository: _Repository(), aiService: _Ai()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final grid = tester.widget<GridView>(find.byType(GridView));
    expect(
      (grid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount)
          .crossAxisCount,
      3,
    );
    expect(find.text('西红柿炒鸡蛋'), findsOneWidget);
    expect(find.text('搜索菜名、分类或食材'), findsOneWidget);
    expect(find.text('制作记录'), findsNothing);
    await tester.enterText(find.byType(TextField).first, '土豆');
    await tester.pump();
    expect(find.text('青椒土豆丝'), findsOneWidget);
    expect(find.text('西红柿炒鸡蛋'), findsNothing);
    await tester.enterText(find.byType(TextField).first, '');
    await tester.pump();
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('库存'));
    await tester.pumpAndSettle();
    expect(find.text('AI推荐菜谱'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('preset editor preserves material and step details when saving', (
    tester,
  ) async {
    final repository = _Repository();
    await tester.pumpWidget(
      MaterialApp(
        home: RecipeFormPage(
          repository: repository,
          recipe: presetRecipes.first,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('编辑为个人版本'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('保存菜谱'),
      450,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('保存菜谱'));
    await tester.pumpAndSettle();
    expect(repository.saved?.name, presetRecipes.first.name);
    expect(repository.saved?.steps.length, 3);
    expect(repository.saved?.seasonings.last.sort, 2);
    expect(tester.takeException(), isNull);
  });
  testWidgets('empty recipe reports validation error without saving', (
    tester,
  ) async {
    final repository = _Repository();
    await tester.pumpWidget(
      MaterialApp(home: RecipeFormPage(repository: repository)),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('保存菜谱'),
      400,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('保存菜谱'));
    await tester.pumpAndSettle();
    expect(find.textContaining('至少一项食材或调料'), findsOneWidget);
    expect(repository.saved, isNull);
  });
}
