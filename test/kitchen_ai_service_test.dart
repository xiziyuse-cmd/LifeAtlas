import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeatlas/features/kitchen/data/kitchen_ai_service.dart';
import 'package:lifeatlas/features/kitchen/data/preset_recipes.dart';
import 'package:lifeatlas/features/kitchen/domain/kitchen_models.dart';

void main() {
  test(
    'kitchen client sends inventory and token, parses complete recipes and rejects malformed results',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));
      var malformed = false;
      server.listen((request) async {
        expect(
          request.headers.value(HttpHeaders.authorizationHeader),
          'Bearer test-token',
        );
        final input =
            jsonDecode(await utf8.decoder.bind(request).join()) as Map;
        expect((input['inventory'] as List).single['name'], '鸡蛋');
        expect(input['instruction'], '少油');
        request.response.headers.contentType = ContentType.json;
        request.response.write(
          jsonEncode({
            'recipes': malformed
                ? [
                    {'name': '坏菜谱'},
                  ]
                : [presetRecipes.first.toMap()],
          }),
        );
        await request.response.close();
      });
      final service = ProxyKitchenAiService(
        endpoint: 'http://127.0.0.1:${server.port}/v1/kitchen/recommend',
        accessTokenProvider: () async => 'test-token',
        allowInsecureHttp: true,
      );
      final inventory = [
        InventoryItem(
          name: '鸡蛋',
          amount: 3,
          unit: '个',
          updatedAt: DateTime.now(),
        ),
      ];
      final recipes = await service.recommend(inventory, '少油');
      expect(recipes.single.name, '西红柿炒鸡蛋');
      expect(recipes.single.steps.length, 3);
      malformed = true;
      await expectLater(
        service.recommend(inventory, '少油'),
        throwsA(isA<KitchenAiException>()),
      );
    },
  );
  test(
    'kitchen client reports login and undeployed endpoint distinctly',
    () async {
      await expectLater(
        ProxyKitchenAiService(
          endpoint: 'https://example.test',
        ).recommend([], ''),
        throwsA(
          isA<KitchenAiException>().having(
            (e) => e.message,
            'message',
            contains('登录'),
          ),
        ),
      );
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));
      server.listen((request) async {
        await request.drain<void>();
        request.response.statusCode = 404;
        request.response.write('not found');
        await request.response.close();
      });
      final service = ProxyKitchenAiService(
        endpoint: 'http://127.0.0.1:${server.port}',
        accessTokenProvider: () async => 'test',
        allowInsecureHttp: true,
      );
      await expectLater(
        service.recommend([], ''),
        throwsA(
          isA<KitchenAiException>().having(
            (e) => e.message,
            'message',
            contains('尚未部署'),
          ),
        ),
      );
    },
  );
}
