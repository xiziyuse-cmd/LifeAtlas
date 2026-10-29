import 'dart:async';
import 'dart:convert';
import 'dart:io';
import '../domain/skincare_models.dart';

/// Community observations remain distinct from the curated, verified catalog.
class BeautyBarcodeService {
  BeautyBarcodeService({HttpClient? client}) : _client = client ?? HttpClient();
  final HttpClient _client;
  Future<SkinProduct?> lookup(String code) async {
    if (!RegExp(r'^\d{8,14}$').hasMatch(code)) {
      throw const FormatException('条码格式无效');
    }
    return (() async {
      final uri = Uri.https(
        'world.openbeautyfacts.org',
        '/api/v2/product/$code.json',
        {
          'fields':
              'code,product_name,brands,quantity,ingredients_text,countries,product_type',
        },
      );
      final request = await _client.getUrl(uri);
      request.followRedirects = false;
      request.headers.set(
        HttpHeaders.userAgentHeader,
        'LifeAtlas/2.0.0 (github.com/xiziyuse-cmd/LifeAtlas)',
      );
      final response = await request.close();
      final bytes = <int>[];
      await for (final chunk in response) {
        bytes.addAll(chunk);
        if (bytes.length > 512 * 1024) throw const FormatException('商品资料过大');
      }
      if (response.statusCode == 404) return null;
      if (response.statusCode != 200) {
        throw StateError('公开产品库暂不可用（${response.statusCode}）');
      }
      return parse(code, object(jsonDecode(utf8.decode(bytes))));
    })().timeout(const Duration(seconds: 20));
  }

  static SkinProduct? parse(String code, Map<String, dynamic> data) {
    if (data['status'] != 1 || data['product'] is! Map) return null;
    final product = object(data['product']);
    final name = product['product_name'] as String? ?? '';
    if (name.trim().isEmpty ||
        (product['code'] != null && product['code'] != code)) {
      return null;
    }
    if (product['product_type'] != null &&
        product['product_type'] != 'beauty') {
      return null;
    }
    return SkinProduct(
      id: skinId(),
      name: name,
      brand: product['brands'] as String? ?? '',
      size: product['quantity'] as String? ?? '',
      region: product['countries'] as String? ?? '',
      barcode: code,
      evidence: 'community',
      source:
          'Open Beauty Facts · https://world.openbeautyfacts.org/product/$code · ODbL',
      ingredients:
          (product['ingredients_text'] is String &&
              (product['ingredients_text'] as String).isNotEmpty)
          ? [product['ingredients_text'] as String]
          : [],
      cautions: '社区资料，版本及用法待核实；请核对包装，功效产品暂不自动安排。',
    );
  }
}
