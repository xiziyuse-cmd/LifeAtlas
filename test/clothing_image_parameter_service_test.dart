import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lifeatlas/features/wardrobe/data/clothing_image_parameter_service.dart';
import 'package:lifeatlas/features/wardrobe/domain/models/clothing_image_parameters.dart';

void main() {
  test('clothing image parameters parse nested measurements safely', () {
    final result = ClothingImageParameters.fromJson({
      'name': '  风衣  ',
      'category': '外套',
      'season_tags': ['春', '秋'],
      'measurements': {
        'clothingLength': 102,
        'chest_circumference': '108.5',
        'trouserLength': 'not-a-number',
      },
    });

    expect(result.name, '风衣');
    expect(result.category, '外套');
    expect(result.seasonTags, ['春', '秋']);
    expect(result.clothingLength, 102);
    expect(result.chestCircumference, 108.5);
    expect(result.trouserLength, isNull);
  });

  test('invalid proxy URL keeps the service unconfigured', () {
    final service = DoubaoProxyClothingImageParameterService(proxyUrl: '');

    expect(service.isConfigured, isFalse);
  });

  test('configured proxy uploads the image and parses the result', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final tempDirectory = await Directory.systemTemp.createTemp(
      'lifeatlas-doubao-test-',
    );
    final image = File(
      '${tempDirectory.path}${Platform.pathSeparator}coat.jpg',
    );
    await image.writeAsBytes([0xff, 0xd8, 0xff, 0xd9]);

    final received = Completer<void>();
    server.listen((request) async {
      expect(request.method, 'POST');
      expect(request.uri.path, '/v1/wardrobe/analyze');
      expect(
        request.headers.value(HttpHeaders.authorizationHeader),
        'Bearer test-token',
      );
      final payload =
          jsonDecode(await utf8.decoder.bind(request).join()) as Map;
      expect(payload['mimeType'], 'image/jpeg');
      expect(payload['imageBase64'], base64Encode(await image.readAsBytes()));

      request.response.headers.contentType = ContentType.json;
      request.response.write(
        jsonEncode({
          'result': {
            'name': '识别外套',
            'category': '外套',
            'seasonTags': ['秋', '冬'],
            'measurements': {'clothingLength': 76, 'chestCircumference': 112},
          },
        }),
      );
      await request.response.close();
      received.complete();
    });

    try {
      final service = DoubaoProxyClothingImageParameterService(
        proxyUrl:
            'http://${InternetAddress.loopbackIPv4.address}:${server.port}/v1/wardrobe/analyze',
        proxyAccessToken: 'test-token',
        allowInsecureHttp: true,
      );

      final result = await service.analyze(image.path);
      await received.future;

      expect(result.name, '识别外套');
      expect(result.category, '外套');
      expect(result.seasonTags, ['秋', '冬']);
      expect(result.clothingLength, 76);
      expect(result.chestCircumference, 112);
    } finally {
      await server.close(force: true);
      await tempDirectory.delete(recursive: true);
    }
  });
}
