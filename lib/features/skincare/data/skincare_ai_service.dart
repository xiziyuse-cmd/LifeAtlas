import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../domain/skincare_models.dart';
import '../domain/skincare_rules.dart';

class SkincareAiService {
  SkincareAiService({this.tokenProvider, HttpClient? client})
    : _client = client ?? HttpClient();
  final Future<String> Function()? tokenProvider;
  final HttpClient _client;
  static const base = String.fromEnvironment(
    'LIFEATLAS_SKINCARE_PROXY_URL',
    defaultValue: 'https://lifeatlas-ai-proxy.xiziyuse.workers.dev/v1/skincare',
  );
  Future<Map<String, dynamic>> _post(
    String action,
    Map<String, dynamic> body,
  ) async {
    if (tokenProvider == null) throw StateError('请先在“我的－AI 服务账号”中登录');
    final uri = Uri.parse('$base/$action');
    if (uri.scheme != 'https' || uri.host.isEmpty) {
      throw StateError('护肤 AI 服务尚未配置');
    }
    try {
      return await (() async {
        final token = await tokenProvider!();
        final req = await _client.postUrl(uri);
        req.followRedirects = false;
        req.headers.contentType = ContentType.json;
        req.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
        req.write(jsonEncode(body));
        final response = await req.close();
        final bytes = <int>[];
        await for (final chunk in response) {
          bytes.addAll(chunk);
          if (bytes.length > 1024 * 1024) throw const FormatException('返回内容过大');
        }
        if (response.statusCode == 404) {
          throw StateError('护肤 AI 接口尚未部署，可使用基础规则方案');
        }
        if (response.statusCode == 401 || response.statusCode == 403) {
          throw StateError('AI 登录已失效，请重新登录');
        }
        if (response.statusCode != 200) {
          throw StateError('护肤 AI 请求失败（${response.statusCode}）');
        }
        return object(jsonDecode(utf8.decode(bytes)));
      })().timeout(const Duration(seconds: 100));
    } on TimeoutException {
      throw StateError('识别或生成超时，请重试');
    } on SocketException {
      throw StateError('无法连接护肤 AI，请检查网络');
    } on FormatException {
      throw StateError('AI 返回格式不完整，请重试');
    }
  }

  Future<SkinProduct> identify(String path) async {
    final file = File(path);
    if (await file.length() > 8 * 1024 * 1024) throw StateError('图片请小于 8MB');
    final bytes = await file.readAsBytes();
    final mime = bytes.length > 3 && bytes[0] == 0x89 && bytes[1] == 0x50
        ? 'image/png'
        : 'image/jpeg';
    final data = await _post('identify', {
      'image': 'data:$mime;base64,${base64Encode(bytes)}',
    });
    final raw = object(data['product']);
    if (raw['name'] is! String || (raw['name'] as String).trim().isEmpty) {
      throw StateError('没有识别到产品名称，请补拍清晰包装');
    }
    // Only retain packaging observations. The model cannot claim verification.
    return SkinProduct(
      id: skinId(),
      name: raw['name'] as String,
      brand: raw['brand'] as String? ?? '',
      category: skinCategories.contains(raw['category'])
          ? raw['category'] as String
          : '其他',
      region: raw['region'] as String? ?? '',
      size: raw['size'] as String? ?? '',
      barcode: raw['barcode'] as String? ?? '',
      evidence: 'ai',
      source: '用户包装照片 · AI 提取待核实',
      image: path,
      ingredients: strings(raw['ingredients']),
      instructions: raw['instructions'] as String? ?? '',
      cautions: raw['cautions'] as String? ?? '包装信息待核实',
    );
  }

  Future<SkinPlan> generate(
    SkinProfile profile,
    List<SkinProduct> products,
  ) async {
    final data = await _post('plan', {
      'profile': profile.toJson(),
      'products': products
          .where((p) => p.usable)
          .map((p) => p.toJson())
          .toList(),
    });
    final plan = SkinPlan.fromJson({
      ...object(data['plan']),
      'id': skinId(),
      'source': 'ai',
      'start': skinDate(DateTime.now()),
    });
    final errors = SkincareRules.validate(plan, products, profile);
    if (errors.isNotEmpty) throw StateError('生成结果需要调整：\n${errors.join('\n')}');
    // Display names always come from the user's cabinet.
    for (final list in [plan.morning, plan.evening]) {
      for (var i = 0; i < list.length; i++) {
        final s = list[i];
        list[i] = SkinStep(
          productId: s.productId,
          name: products.firstWhere((p) => p.id == s.productId).name,
          amount: s.amount,
          area: s.area,
          note: s.note,
          days: s.days,
        );
      }
    }
    return plan;
  }
}
