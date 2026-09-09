import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeatlas/features/kitchen/data/kitchen_ai_service.dart';
import 'package:lifeatlas/features/kitchen/data/kitchen_repository.dart';
import 'package:lifeatlas/features/kitchen/data/preset_recipes.dart';
import 'package:lifeatlas/features/kitchen/domain/kitchen_models.dart';
import 'package:lifeatlas/features/kitchen/presentation/kitchen_page.dart';
import 'package:lifeatlas/features/kitchen/presentation/inventory_form_dialog.dart';
import 'package:lifeatlas/features/kitchen/presentation/recipe_form_page.dart';

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
    await tester.testTextInput.receiveAction(TextInputAction.done);
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
    expect(find.textContaining('至少添加一项食材'), findsOneWidget);
    expect(repository.saved, isNull);
  });
}
