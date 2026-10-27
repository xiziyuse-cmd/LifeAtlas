import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeatlas/core/database/app_database.dart';
import 'package:lifeatlas/features/kitchen/data/kitchen_repository.dart';
import 'package:lifeatlas/features/kitchen/domain/kitchen_models.dart';
import 'package:lifeatlas/features/kitchen/domain/shopping_list.dart';
import 'package:lifeatlas/features/kitchen/presentation/shopping_list_page.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

const _recipes = [
  Recipe(
    id: 1,
    name: '土豆鸡肉',
    materials: [
      RecipeMaterial(name: '鸡肉', amount: 100, unit: 'g'),
      RecipeMaterial(name: '土豆', amount: 200, unit: 'g'),
    ],
    seasonings: [RecipeMaterial(name: '盐', amount: 1, unit: '勺')],
  ),
  Recipe(
    id: 2,
    name: '香菇鸡肉',
    materials: [
      RecipeMaterial(name: '鸡肉', amount: 150, unit: 'g'),
      RecipeMaterial(name: '香菇'),
    ],
    seasonings: [RecipeMaterial(name: '盐', amount: 0.5, unit: '勺')],
  ),
];

class _Repository extends KitchenRepository {
  List<Recipe> recipes = [..._recipes];
  ShoppingListState state = const ShoppingListState();
  bool failSave = false;
  @override
  Future<List<Recipe>> listRecipes() async => recipes;
  @override
  Future<ShoppingListState> loadShoppingList() async => state;
  @override
  Future<void> saveShoppingList(ShoppingListState value) async {
    if (failSave) throw StateError('storage unavailable');
    state = value;
  }
}

void main() {
  test('decimal totals stay readable', () {
    final items = buildShoppingList(const [
      Recipe(
        name: '小数',
        materials: [
          RecipeMaterial(name: '盐', amount: 0.1, unit: 'g'),
          RecipeMaterial(name: '盐', amount: 0.2, unit: 'g'),
        ],
      ),
    ]);
    expect(items.single.quantity, '0.3g');
  });
  test(
    'aggregates same unit once per recipe and orders foods before spices',
    () {
      final items = buildShoppingList([..._recipes, _recipes.first]);
      expect(items.map((i) => i.name), ['鸡肉', '土豆', '香菇', '盐']);
      expect(items.map((i) => i.quantity), ['250g', '200g', '用量待补', '1.5勺']);
      expect(items.last.seasoning, true);
      expect(buildShoppingList([]), isEmpty);
    },
  );

  test(
    'keeps units and categories separate and does not lose unknown amounts',
    () {
      final items = buildShoppingList(const [
        Recipe(
          name: '混合',
          materials: [
            RecipeMaterial(name: ' Chicken ', amount: 100, unit: 'g'),
            RecipeMaterial(name: 'chicken', amount: 0.5, unit: 'kg'),
            RecipeMaterial(name: 'chicken', unit: 'g'),
            RecipeMaterial(name: '鸡肉'),
          ],
          seasonings: [RecipeMaterial(name: 'chicken', amount: 1, unit: 'g')],
        ),
      ]);
      expect(items.length, 4);
      expect(items.first.quantity, '100g + 用量待补');
      expect(items[1].quantity, '0.5kg');
      expect(items[2].quantity, '用量待补');
      expect(items.last.quantity, '1g');
      expect(items.first.key, isNot(items.last.key));
    },
  );

  test('quantity changes invalidate tick identity and state round trips', () {
    final one = buildShoppingList([_recipes.first]).first;
    final two = buildShoppingList(_recipes).first;
    expect(one.key, isNot(two.key));
    final state = ShoppingListState(recipeIds: {1, 2}, prepared: {two.key});
    final saved = ShoppingListState.decode(state.encode());
    expect(saved.recipeIds, {1, 2});
    expect(saved.prepared, {two.key});
  });

  test(
    'selection persists across actual database close and reopen without touching other data',
    () async {
      sqfliteFfiInit();
      final dir = await Directory.systemTemp.createTemp('shopping-list-');
      final path = '${dir.path}/app.db';
      var database = AppDatabase(
        factory: databaseFactoryFfi,
        databasePath: path,
      );
      var repository = KitchenRepository(database: database);
      expect((await repository.loadShoppingList()).recipeIds, isEmpty);
      await (await database.database).insert('app_settings', {
        'setting_key': 'test_preserve',
        'setting_value': 'keep',
      });
      final state = ShoppingListState(
        recipeIds: {1, 2},
        prepared: {buildShoppingList(_recipes).first.key},
      );
      await repository.saveShoppingList(state);
      await database.close();
      database = AppDatabase(factory: databaseFactoryFfi, databasePath: path);
      addTearDown(() async {
        await database.close();
        await databaseFactoryFfi.deleteDatabase(path);
        await dir.delete();
      });
      repository = KitchenRepository(database: database);
      final loaded = await repository.loadShoppingList();
      expect(loaded.recipeIds, state.recipeIds);
      expect(loaded.prepared, state.prepared);
      final db = await database.database;
      expect(await db.getVersion(), 10);
      expect(
        (await db.query(
          'app_settings',
          where: 'setting_key = ?',
          whereArgs: ['test_preserve'],
        )).single['setting_value'],
        'keep',
      );
    },
  );

  testWidgets(
    'multi select creates list, ticks fade both fields and survive reopening',
    (tester) async {
      final repository = _Repository();
      await tester.pumpWidget(
        MaterialApp(home: ShoppingListPage(repository: repository)),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('选择菜谱（已选0道）'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('土豆鸡肉'));
      await tester.tap(find.text('香菇鸡肉'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('确定（2）'));
      await tester.pumpAndSettle();
      expect(find.text('250g'), findsOneWidget);
      expect(find.text('1.5勺'), findsOneWidget);
      expect(find.text('用量待补'), findsOneWidget);
      expect(
        tester.getTopLeft(find.text('香菇')).dy,
        lessThan(tester.getTopLeft(find.byType(Divider)).dy),
      );
      expect(
        tester.getTopLeft(find.byType(Divider)).dy,
        lessThan(tester.getTopLeft(find.text('盐')).dy),
      );
      await tester.tap(find.byType(Checkbox).first);
      await tester.pumpAndSettle();
      expect(find.text('已准备 1/4'), findsOneWidget);
      expect(
        tester.widget<Text>(find.text('鸡肉')).style!.color,
        Colors.grey.shade400,
      );
      expect(
        tester.widget<Text>(find.text('250g')).style!.color,
        Colors.grey.shade400,
      );
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(
        MaterialApp(home: ShoppingListPage(repository: repository)),
      );
      await tester.pumpAndSettle();
      expect(tester.widget<Checkbox>(find.byType(Checkbox).first).value, true);
      await tester.tap(find.text('鸡肉'));
      await tester.pumpAndSettle();
      expect(repository.state.prepared, isEmpty);
      expect(
        tester.widget<Text>(find.text('鸡肉')).style!.color,
        isNot(Colors.grey.shade400),
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('changed totals and deleted recipes prune saved ticks', (
    tester,
  ) async {
    final repository = _Repository();
    repository.state = ShoppingListState(
      recipeIds: {1, 2, 999},
      prepared: {buildShoppingList(_recipes).first.key},
    );
    repository.recipes = [_recipes.first];
    await tester.pumpWidget(
      MaterialApp(home: ShoppingListPage(repository: repository)),
    );
    await tester.pumpAndSettle();
    expect(find.text('100g'), findsOneWidget);
    expect(find.text('已准备 0/3'), findsOneWidget);
    expect(repository.state.recipeIds, {1});
    expect(repository.state.prepared, isEmpty);
  });

  testWidgets('save failure keeps prior tick and shows retryable error', (
    tester,
  ) async {
    final repository = _Repository()
      ..state = const ShoppingListState(recipeIds: {1});
    await tester.pumpWidget(
      MaterialApp(home: ShoppingListPage(repository: repository)),
    );
    await tester.pumpAndSettle();
    repository.failSave = true;
    await tester.tap(find.byType(Checkbox).first);
    await tester.pumpAndSettle();
    expect(repository.state.prepared, isEmpty);
    expect(tester.widget<Checkbox>(find.byType(Checkbox).first).value, false);
    expect(find.textContaining('购物清单保存失败'), findsOneWidget);
    repository.failSave = false;
    await tester.tap(find.byType(Checkbox).first);
    await tester.pumpAndSettle();
    expect(repository.state.prepared.length, 1);
  });

  testWidgets('empty recipes and empty ingredients show useful states', (
    tester,
  ) async {
    final repository = _Repository()..recipes = [];
    await tester.pumpWidget(
      MaterialApp(home: ShoppingListPage(repository: repository)),
    );
    await tester.pumpAndSettle();
    expect(find.text('暂无菜谱，先添加菜谱'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    repository.recipes = [const Recipe(id: 3, name: '空菜谱')];
    repository.state = const ShoppingListState(recipeIds: {3});
    await tester.pumpWidget(
      MaterialApp(home: ShoppingListPage(repository: repository)),
    );
    await tester.pumpAndSettle();
    expect(find.text('所选菜谱暂无食材或调料'), findsOneWidget);
    expect(find.byType(Divider), findsNothing);
  });

  testWidgets('narrow large text layout and picker search remain usable', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repository = _Repository()
      ..state = const ShoppingListState(recipeIds: {1, 2});
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(1.6)),
          child: child!,
        ),
        home: ShoppingListPage(repository: repository),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('选择菜谱（已选2道）'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.enterText(find.byType(TextField), '香菇');
    await tester.pumpAndSettle();
    expect(find.text('土豆鸡肉'), findsNothing);
    expect(find.text('香菇鸡肉'), findsOneWidget);
    await tester.tap(find.text('香菇鸡肉'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('确定（1）'));
    await tester.pumpAndSettle();
    expect(repository.state.recipeIds, {1});
    expect(find.text('100g'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
