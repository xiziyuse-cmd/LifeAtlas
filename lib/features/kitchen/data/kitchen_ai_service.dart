import 'dart:async';
import 'dart:convert';
import 'dart:io';
import '../domain/kitchen_models.dart';

abstract interface class KitchenAiService {
  Future<List<Recipe>> recommend(
    List<InventoryItem> inventory,
    String instruction,
  );
}

/// Future capabilities intentionally have no fabricated implementation.
abstract interface class KitchenAiExtensions {
  Future<({String name, List<String> possibleMaterials, String possibleMethod})>
  identifyDish(String imagePath);
  Future<Recipe> optimizeRecipe(Recipe recipe, String instruction);
}

class ProxyKitchenAiService implements KitchenAiService {
  ProxyKitchenAiService({
    required this.endpoint,
    this.accessTokenProvider,
    this.allowInsecureHttp = false,
    HttpClient? client,
    this.timeout = const Duration(seconds: 100),
  }) : _client = client ?? HttpClient();
  final String endpoint;
  final bool allowInsecureHttp;
  final Future<String> Function()? accessTokenProvider;
  final Duration timeout;
  final HttpClient _client;
  @override
  Future<List<Recipe>> recommend(
    List<InventoryItem> inventory,
    String instruction,
  ) async {
    if (accessTokenProvider == null) {
      throw const KitchenAiException('请先在“我的－AI 服务账号”中登录');
    }
    final uri = Uri.tryParse(endpoint);
    if (uri == null ||
        (uri.scheme != 'https' &&
            !(allowInsecureHttp && uri.scheme == 'http')) ||
        uri.host.isEmpty) {
      throw const KitchenAiException('厨房 AI 服务尚未配置');
    }
    try {
      final token = await accessTokenProvider!();
      return await _request(
        uri,
        token,
        inventory,
        instruction,
      ).timeout(timeout);
    } on TimeoutException {
      throw const KitchenAiException('AI 推荐超时，请重试');
    } on SocketException {
      throw const KitchenAiException('无法连接 AI 服务，请检查网络');
    } on HttpException {
      throw const KitchenAiException('AI 请求失败，请重试');
    } on FormatException {
      throw const KitchenAiException('AI 返回的菜谱不完整，请重新推荐');
    } on TypeError {
      throw const KitchenAiException('AI 返回格式错误，请重新推荐');
    }
  }

  Future<List<Recipe>> _request(
    Uri uri,
    String token,
    List<InventoryItem> inventory,
    String instruction,
  ) async {
    final request = await _client.postUrl(uri);
    request.followRedirects = false;
    request.headers.contentType = ContentType.json;
    request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
    request.write(
      jsonEncode({
        'inventory': inventory
            .map((i) => {...i.toMap(), 'remaining_days': i.remainingDays()})
            .toList(),
        'instruction': instruction,
      }),
    );
    final response = await request.close();
    final bytes = <int>[];
    await for (final chunk in response) {
      bytes.addAll(chunk);
      if (bytes.length > 1024 * 1024) {
        throw const FormatException('Response too large');
      }
    }
    if (response.statusCode == 404) {
      throw const KitchenAiException('厨房 AI 接口尚未部署，请更新代理服务');
    }
    if (response.statusCode == 401 || response.statusCode == 403) {
      throw const KitchenAiException('登录状态已失效，请重新登录');
    }
    if (response.statusCode != 200) {
      throw KitchenAiException('AI 推荐失败（${response.statusCode}），请稍后重试');
    }
    final data = jsonDecode(utf8.decode(bytes)) as Map;
    final recipes = (data['recipes'] as List)
        .map((m) => Recipe.fromMap(Map<String, Object?>.from(m as Map)))
        .toList();
    if (recipes.isEmpty || recipes.length > 5) {
      throw const FormatException('Invalid recipes');
    }
    for (final r in recipes) {
      r.validate();
      if (r.image.isNotEmpty ||
          r.steps.any((s) => s.image.isNotEmpty || s.video.isNotEmpty)) {
        throw const FormatException('Unexpected media');
      }
    }
    return recipes;
  }
}

class KitchenAiException implements Exception {
  const KitchenAiException(this.message);
  final String message;
  @override
  String toString() => message;
}

String inventoryAvailability(
  RecipeMaterial material,
  List<InventoryItem> inventory, {
  DateTime? now,
}) {
  final today = DateTime.parse(kitchenDate(now ?? DateTime.now()));
  final matches = inventory
      .where(
        (i) =>
            i.name.trim() == material.name.trim() &&
            i.amount > 0 &&
            (i.expireDate == null || !i.expireDate!.isBefore(today)),
      )
      .toList();
  if (matches.isEmpty) return '缺少';
  final sameUnit = matches.where((i) => i.unit.trim() == material.unit.trim());
  if (sameUnit.isEmpty) return '已有 · 单位待确认';
  return sameUnit.fold<double>(0, (sum, i) => sum + i.amount) >= material.amount
      ? '✓ 已有'
      : '数量不足';
}
