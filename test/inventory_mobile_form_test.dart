import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeatlas/features/kitchen/data/kitchen_ai_service.dart';
import 'package:lifeatlas/features/kitchen/data/kitchen_repository.dart';
import 'package:lifeatlas/features/kitchen/domain/kitchen_models.dart';
import 'package:lifeatlas/features/kitchen/presentation/inventory_form_dialog.dart';
import 'package:lifeatlas/features/kitchen/presentation/kitchen_page.dart';

class _Repository extends KitchenRepository {
  InventoryItem? saved;
  @override
  Future<List<Recipe>> listRecipes() async => [];
  @override
  Future<List<InventoryItem>> listInventory() async =>
      saved == null ? [] : [saved!];
  @override
  Future<List<FoodBaseInfo>> listFoodBaseInfo() async => [];
  @override
  Future<void> saveInventory(InventoryItem item) async => saved = item;
}

class _Ai implements KitchenAiService {
  @override
  Future<List<Recipe>> recommend(
    List<InventoryItem> inventory,
    String instruction,
  ) async => [];
}

Future<void> scrollTo(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(
    finder,
    200,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'inventory opens full page, saves decimal quantities and returns to stock',
    (tester) async {
      final repository = _Repository();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: KitchenPage(repository: repository, aiService: _Ai()),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('库存'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('新增库存'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.byType(InventoryFormDialog), findsOneWidget);
      await tester.enterText(find.widgetWithText(TextField, '食物名称'), '面粉');
      await tester.enterText(find.widgetWithText(TextField, '数量'), '0.5');
      await tester.tap(find.widgetWithText(ChoiceChip, 'kg'));
      await tester.tap(find.text('保存库存'));
      await tester.pumpAndSettle();
      expect(repository.saved!.name, '面粉');
      expect(repository.saved!.amount, 0.5);
      expect(repository.saved!.unit, 'kg');
      expect(find.byType(InventoryFormDialog), findsNothing);
      expect(find.text('面粉  0.5kg'), findsOneWidget);
    },
  );

  testWidgets(
    'failed inventory save keeps form and custom units, retry succeeds',
    (tester) async {
      bool fail = true;
      InventoryItem? saved;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => InventoryFormDialog(
                      foods: const [],
                      onSave: (item) async {
                        if (fail) throw StateError('disk');
                        saved = item;
                      },
                    ),
                  ),
                ),
                child: const Text('录入'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('录入'));
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextField, '食物名称'), '自定义');
      await tester.enterText(find.widgetWithText(TextField, '数量'), '0');
      await tester.enterText(find.widgetWithText(TextField, '单位'), '小袋');
      await tester.tap(find.text('保存库存'));
      await tester.pumpAndSettle();
      expect(find.text('库存保存失败，请重试，填写内容已保留'), findsOneWidget);
      expect(
        tester
            .widget<TextField>(find.widgetWithText(TextField, '单位'))
            .controller!
            .text,
        '小袋',
      );
      fail = false;
      await tester.tap(find.text('保存库存'));
      await tester.pumpAndSettle();
      expect(saved!.amount, 0);
      expect(saved!.unit, '小袋');
      expect(find.byType(InventoryFormDialog), findsNothing);
    },
  );

  testWidgets(
    'inventory mobile keyboard keeps save visible and dates editable',
    (tester) async {
      tester.view.physicalSize = const Size(320, 720);
      tester.view.devicePixelRatio = 1;
      tester.view.viewInsets = FakeViewPadding(bottom: 260);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetViewInsets);
      final item = InventoryItem(
        id: 7,
        name: '牛奶',
        amount: 2,
        unit: '盒',
        purchaseDate: DateTime(2026, 10, 20),
        shelfLifeDays: 10,
        expireDate: DateTime(2026, 10, 30),
        remark: '冷藏',
        updatedAt: DateTime(2026, 10, 20),
      );
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(1.5)),
            child: child!,
          ),
          home: InventoryFormDialog(item: item, foods: const []),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.getBottomRight(find.text('保存库存')).dy, lessThan(460));
      await scrollTo(tester, find.widgetWithText(TextField, '保质期（天）'));
      await tester.enterText(find.widgetWithText(TextField, '保质期（天）'), '12');
      await tester.pumpAndSettle();
      expect(find.text('2026-11-01'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
