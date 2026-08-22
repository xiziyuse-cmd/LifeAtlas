import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lifeatlas/features/wardrobe/data/preorder_analysis_service.dart';
import 'package:lifeatlas/features/wardrobe/data/wardrobe_repository.dart';
import 'package:lifeatlas/features/wardrobe/domain/models/clothing_item.dart';
import 'package:lifeatlas/features/wardrobe/domain/models/preorder_item.dart';

import 'support/test_database.dart';

void main() {
  test('invalid text proxy URL keeps analysis unconfigured', () async {
    final database = await openTestAppDatabase();
    addTearDown(database.close);
    final service = DoubaoProxyPreorderAnalysisService(
      proxyUrl: '',
      wardrobeRepository: WardrobeRepository(database: database),
    );

    expect(service.isConfigured, isFalse);
  });

  test('preorder analysis sends wardrobe summary and parses usage', () async {
    final database = await openTestAppDatabase();
    addTearDown(database.close);
    final repository = WardrobeRepository(database: database);
    final now = DateTime.utc(2026, 8, 22);
    await repository.createClothing(
      ClothingItem(
        name: '米色风衣',
        imagePath: 'images/coat.jpg',
        category: '外套',
        color: '米色',
        seasonTags: const ['春', '秋'],
        createdAt: now,
        updatedAt: now,
      ),
    );

    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final received = Completer<void>();
    server.listen((request) async {
      expect(request.uri.path, '/v1/wardrobe/preorder-analysis');
      expect(
        request.headers.value(HttpHeaders.authorizationHeader),
        'Bearer proxy-token',
      );
      final payload =
          jsonDecode(await utf8.decoder.bind(request).join()) as Map;
      expect((payload['item'] as Map)['name'], '黑色夹克');
      expect((payload['wardrobe'] as List).single['name'], '米色风衣');
      expect(payload['userInstruction'], '重点分析是否重复');

      request.response.headers.contentType = ContentType.json;
      request.response.write(
        jsonEncode({
          'resultText': '与已有风衣用途部分重合，建议谨慎购买。',
          'promptVersion': 'preorder-v1',
          'model': 'doubao-seed-2-1-turbo-260628',
          'usage': {
            'prompt_tokens': 120,
            'completion_tokens': 80,
            'total_tokens': 200,
          },
        }),
      );
      await request.response.close();
      received.complete();
    });

    try {
      final service = DoubaoProxyPreorderAnalysisService(
        proxyUrl:
            'http://${InternetAddress.loopbackIPv4.address}:${server.port}/v1/wardrobe/preorder-analysis',
        proxyAccessToken: 'proxy-token',
        wardrobeRepository: repository,
        allowInsecureHttp: true,
      );
      final result = await service.analyze(
        item: PreorderItem(
          name: '黑色夹克',
          imagePath: 'images/wanted.jpg',
          category: '外套',
          price: 899,
          createdAt: now,
          updatedAt: now,
        ),
        userInstruction: '重点分析是否重复',
      );
      await received.future;

      expect(result.model, 'doubao-seed-2-1-turbo-260628');
      expect(result.promptVersion, 'preorder-v1');
      expect(result.resultText, contains('谨慎购买'));
      expect(result.inputTokens, 120);
      expect(result.outputTokens, 80);
      expect(result.totalTokens, 200);
    } finally {
      await server.close(force: true);
    }
  });
}
