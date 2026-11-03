import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeatlas/features/kitchen/domain/kitchen_export.dart';
import 'package:lifeatlas/features/kitchen/domain/kitchen_models.dart';
import 'package:lifeatlas/features/kitchen/domain/shopping_list.dart';
import 'package:lifeatlas/features/kitchen/presentation/export_image_renderer.dart';
import 'package:lifeatlas/features/kitchen/presentation/kitchen_export_page.dart';
import 'package:lifeatlas/features/kitchen/presentation/recipe_detail_page.dart';
import 'package:lifeatlas/features/kitchen/data/kitchen_repository.dart';

const dish = Recipe(
  id: 1,
  name: '香菇鸡肉',
  materials: [
    RecipeMaterial(name: '鸡肉', amount: 100, unit: 'g', remark: '切块'),
    RecipeMaterial(name: '香菇'),
  ],
  seasonings: [RecipeMaterial(name: '盐', amount: 1, unit: '勺')],
  steps: [
    RecipeStep(name: '炖煮', content: '小火炖熟。', duration: 20),
    RecipeStep(
      name: '准备配菜',
      content: '洗净切块。',
      duration: 5,
      parallelWithPrevious: true,
    ),
  ],
);
void main() {
  testWidgets(
    'image export shares every PNG with a valid origin and only cleans expired export cache',
    (tester) async {
      late List<int> png;
      final temp = Directory('build/export-share-test').absolute;
      late File old;
      late File original;
      await tester.runAsync(() async {
        final rec = ui.PictureRecorder();
        Canvas(rec).drawColor(Colors.white, BlendMode.src);
        final picture = rec.endRecording();
        final image = await picture.toImage(2, 2);
        png = (await image.toByteData(
          format: ui.ImageByteFormat.png,
        ))!.buffer.asUint8List();
        image.dispose();
        picture.dispose();
        await Directory('${temp.path}/kitchen_exports').create(recursive: true);
        old = File('${temp.path}/kitchen_exports/export-old.png');
        await old.writeAsBytes(png);
        await old.setLastModified(
          DateTime.now().subtract(const Duration(days: 2)),
        );
        original = File('${temp.path}/recipe-original.png');
        await original.writeAsBytes(png);
      });
      Map? shared;
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/path_provider'),
        (_) async => temp.path,
      );
      messenger.setMockMethodCallHandler(
        const MethodChannel('dev.fluttercommunity.plus/share'),
        (call) async {
          shared = call.arguments as Map;
          return 'dev.fluttercommunity.plus/share/dismissed';
        },
      );
      addTearDown(
        () => messenger.setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          null,
        ),
      );
      addTearDown(
        () => messenger.setMockMethodCallHandler(
          const MethodChannel('dev.fluttercommunity.plus/share'),
          null,
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: KitchenExportPage(
            document: KitchenExport.recipe(dish),
            renderer: (_) async => ExportImages([
              Uint8List.fromList(png),
              Uint8List.fromList(png),
            ]),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('分享图片'));
      for (var attempt = 0; attempt < 200 && shared == null; attempt++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
        await tester.pump(const Duration(milliseconds: 20));
      }
      await tester.pumpAndSettle();
      expect(shared?['paths'], hasLength(2));
      expect(shared?['mimeTypes'], ['image/png', 'image/png']);
      expect(shared?['originWidth'], greaterThan(0));
      await tester.runAsync(() async {
        for (final path in shared!['paths'] as List) {
          expect(await File(path as String).readAsBytes(), png);
        }
        expect(await old.exists(), isFalse);
        expect(await original.exists(), isTrue);
      });
      expect(find.text('分享成功'), findsNothing);
    },
  );
  test(
    'recipe exports original quantities, remarks, ordered steps and parallel duration',
    () {
      final doc = KitchenExport.recipe(dish);
      expect(doc.text, contains('预计制作 20 分钟'));
      expect(doc.text, contains('鸡肉  100g（切块）'));
      expect(doc.text, contains('香菇  用量待补'));
      expect(doc.text, contains('2. 准备配菜 · 5分钟 · 与上一步并行'));
    },
  );
  test(
    'shopping export uses scaled merged amounts and snapshots prepared state without writes',
    () {
      final rows = buildShoppingList([dish], servings: {1: 3});
      final state = ShoppingListState(
        recipeIds: {1},
        servings: {1: 3},
        prepared: {rows.first.key},
      );
      final before = state.encode();
      final doc = KitchenExport.shopping([
        dish,
        const Recipe(id: 2, name: '未选菜谱'),
      ], state);
      expect(doc.text, contains('香菇鸡肉 × 3份'));
      expect(doc.text, contains('[已准备] 鸡肉  300g'));
      expect(doc.text, contains('[待准备] 香菇  用量待补'));
      expect(doc.text, contains('盐  3勺'));
      expect(doc.text, isNot(contains('未选菜谱')));
      expect(state.encode(), before);
    },
  );
  testWidgets(
    'real PNG generation paginates long Chinese content and missing photo degrades with warning',
    (tester) async {
      await tester.runAsync(() async {
        String? family;
        final font = File('C:/Windows/Fonts/msyh.ttc');
        if (await font.exists()) {
          final loader = FontLoader('ExportQA')
            ..addFont(
              Future.value(ByteData.sublistView(await font.readAsBytes())),
            );
          await loader.load();
          family = 'ExportQA';
        }
        final long = KitchenExport(
          title: '香菇鸡肉 · 完整菜谱',
          image: 'assets/images/recipes/banana-pancake.jpg',
          sections: [
            '食材\n鸡肉 300g\n香菇 用量待补\n盐 3勺',
            for (var i = 1; i <= 75; i++) '$i. 制作步骤\n小火炖煮，确认食材熟透后再调味。可与准备配菜并行。',
            '结束标记：所有步骤完整导出。',
          ],
        );
        final output = await ExportImageRenderer.render(
          long,
          fontFamily: family,
        );
        expect(output.pages.length, greaterThan(3));
        expect(output.warning, isEmpty);
        final folder = Directory('build/export-qa')
          ..createSync(recursive: true);
        for (var i = 0; i < output.pages.length; i++) {
          final codec = await ui.instantiateImageCodec(output.pages[i]);
          final frame = await codec.getNextFrame();
          expect(frame.image.width, 800);
          expect(frame.image.height, 1120);
          final rgba = await frame.image.toByteData(
            format: ui.ImageByteFormat.rawRgba,
          );
          var ink = 0;
          for (var y = 26; y < 65; y++) {
            for (var x = 48; x < 350; x++) {
              if (rgba!.getUint8((y * 800 + x) * 4) < 160) ink++;
            }
          }
          expect(
            ink,
            greaterThan(20),
            reason: 'page ${i + 1} header must rasterize',
          );
          frame.image.dispose();
          codec.dispose();
          await File(
            '${folder.path}/recipe-${i + 1}.png',
          ).writeAsBytes(output.pages[i]);
        }
        final failed = await ExportImageRenderer.render(
          KitchenExport(
            title: '缺图菜谱',
            image: 'assets/missing.jpg',
            sections: ['仍可导出文字'],
          ),
        );
        expect(failed.pages, isNotEmpty);
        expect(failed.warning, contains('主图未能载入'));
        await expectLater(
          ExportImageRenderer.render(
            KitchenExport(title: '超长', sections: ['长' * 200001]),
          ),
          throwsFormatException,
        );
      });
    },
  );
  testWidgets(
    'text preview copies exact content and failed share can retry; dismissal is not success',
    (tester) async {
      var fail = true;
      Map? shared;
      String? copied;
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(
        const MethodChannel('dev.fluttercommunity.plus/share'),
        (call) async {
          if (fail) throw PlatformException(code: 'failed');
          shared = call.arguments as Map;
          return 'dev.fluttercommunity.plus/share/dismissed';
        },
      );
      messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map)['text'] as String;
        }
        return null;
      });
      addTearDown(
        () => messenger.setMockMethodCallHandler(
          const MethodChannel('dev.fluttercommunity.plus/share'),
          null,
        ),
      );
      addTearDown(
        () => messenger.setMockMethodCallHandler(SystemChannels.platform, null),
      );
      final doc = KitchenExport.shopping([
        dish,
      ], const ShoppingListState(recipeIds: {1}));
      await tester.pumpWidget(
        MaterialApp(
          home: KitchenExportPage(
            document: doc,
            asImage: false,
            allowText: true,
          ),
        ),
      );
      await tester.tap(find.text('复制文字'));
      await tester.pumpAndSettle();
      expect(copied, doc.text);
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      await tester.tap(find.text('分享文字'));
      await tester.pumpAndSettle();
      expect(find.textContaining('导出失败'), findsOneWidget);
      fail = false;
      await tester.tap(find.text('分享文字'));
      await tester.pumpAndSettle();
      expect(shared?['text'], doc.text);
      expect(shared?['originWidth'], greaterThan(0));
      expect(find.text('分享成功'), findsNothing);
    },
  );
  testWidgets(
    'image generation failure retries and recipe page exposes image export for any source',
    (tester) async {
      var count = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: KitchenExportPage(
            document: KitchenExport.recipe(dish),
            renderer: (doc) async {
              count++;
              throw StateError('failed');
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('重试'), findsOneWidget);
      await tester.tap(find.text('重试'));
      await tester.pumpAndSettle();
      expect(count, 2);
      await tester.pumpWidget(
        MaterialApp(
          home: RecipeDetailPage(recipe: dish, repository: KitchenRepository()),
        ),
      );
      expect(find.byTooltip('导出图片'), findsOneWidget);
    },
  );
}
