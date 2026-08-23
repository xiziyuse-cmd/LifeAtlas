import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../../../core/auth/ai_auth_session.dart';
import '../domain/models/preorder_analysis.dart';
import '../domain/models/preorder_item.dart';
import 'wardrobe_repository.dart';

/// Provides AI-backed purchase advice for a single preorder item.
///
/// The default implementation is deliberately unavailable. Applications must
/// inject a configured implementation before an analysis can be produced or
/// persisted.
abstract interface class PreorderAnalysisService {
  bool get isConfigured;

  Future<PreorderAnalysisResult> analyze({
    required PreorderItem item,
    String? userInstruction,
  });
}

class PreorderAnalysisResult {
  const PreorderAnalysisResult({
    required this.promptVersion,
    required this.model,
    required this.resultText,
    this.resultJson,
    this.inputTokens,
    this.outputTokens,
    this.totalTokens,
  });

  final String promptVersion;
  final String model;
  final String resultText;
  final String? resultJson;
  final int? inputTokens;
  final int? outputTokens;
  final int? totalTokens;

  PreorderAnalysis toRecord({
    required int preorderItemId,
    DateTime? analyzedAt,
  }) {
    return PreorderAnalysis(
      preorderItemId: preorderItemId,
      promptVersion: promptVersion,
      model: model,
      resultText: resultText,
      resultJson: resultJson,
      inputTokens: inputTokens,
      outputTokens: outputTokens,
      totalTokens: totalTokens,
      analyzedAt: analyzedAt ?? DateTime.now(),
    );
  }
}

class UnconfiguredPreorderAnalysisService implements PreorderAnalysisService {
  const UnconfiguredPreorderAnalysisService();

  @override
  bool get isConfigured => false;

  @override
  Future<PreorderAnalysisResult> analyze({
    required PreorderItem item,
    String? userInstruction,
  }) async {
    throw const PreorderAnalysisUnavailableException();
  }
}

class DoubaoProxyPreorderAnalysisService implements PreorderAnalysisService {
  DoubaoProxyPreorderAnalysisService({
    required String proxyUrl,
    required this.wardrobeRepository,
    this.accessTokenProvider,
    bool allowInsecureHttp = false,
    this.timeout = const Duration(seconds: 60),
    HttpClient? httpClient,
  }) : _endpoint = _parseEndpoint(proxyUrl, allowInsecureHttp),
       _httpClient = httpClient ?? HttpClient();

  final Uri? _endpoint;
  final WardrobeRepository wardrobeRepository;
  final Future<String> Function()? accessTokenProvider;
  final Duration timeout;
  final HttpClient _httpClient;

  @override
  bool get isConfigured => _endpoint != null;

  @override
  Future<PreorderAnalysisResult> analyze({
    required PreorderItem item,
    String? userInstruction,
  }) async {
    final endpoint = _endpoint;
    if (endpoint == null) {
      throw const PreorderAnalysisUnavailableException();
    }

    try {
      final tokenProvider = accessTokenProvider;
      if (tokenProvider == null) {
        throw const AiAuthenticationException('请先在“我的－AI 服务账号”中登录');
      }
      final accessToken = await tokenProvider();
      final wardrobe = await wardrobeRepository.listClothing();
      final request = await _httpClient.postUrl(endpoint).timeout(timeout);
      request.headers.contentType = ContentType.json;
      request.headers.set(HttpHeaders.acceptHeader, ContentType.json.mimeType);
      request.headers.set(
        HttpHeaders.authorizationHeader,
        'Bearer $accessToken',
      );
      request.write(
        jsonEncode({
          'item': _preorderSummary(item),
          'wardrobe': [
            for (final clothing in wardrobe.take(100))
              {
                'name': clothing.name,
                'brand': clothing.brand,
                'category': clothing.category,
                'seasonTags': clothing.seasonTags,
                'color': clothing.color,
                'material': clothing.material,
                'size': clothing.size,
                'wearCount': clothing.wearCount,
                'minWornTemperature': clothing.minWornTemperature,
                'maxWornTemperature': clothing.maxWornTemperature,
                'parameters': {
                  for (final entry in clothing.parameterValues.entries.take(30))
                    entry.key: entry.value.numberValue ?? entry.value.textValue,
                },
              },
          ],
          'userInstruction': _normalize(userInstruction),
        }),
      );

      final response = await request.close().timeout(timeout);
      final responseText = await utf8.decoder
          .bind(response)
          .join()
          .timeout(timeout);
      final decoded = _decodeObject(responseText);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw PreorderAnalysisRequestException(
          _safeErrorMessage(decoded, response.statusCode),
        );
      }

      final resultText = _string(decoded['resultText']);
      if (resultText == null) {
        throw const PreorderAnalysisRequestException('AI 分析服务返回了空结果');
      }
      final usage = _optionalObjectMap(decoded['usage']);
      final resultJson = decoded['resultJson'];
      return PreorderAnalysisResult(
        promptVersion: _string(decoded['promptVersion']) ?? 'preorder-v1',
        model: _string(decoded['model']) ?? 'unknown',
        resultText: resultText,
        resultJson: resultJson == null ? null : jsonEncode(resultJson),
        inputTokens: _integer(
          usage?['prompt_tokens'] ?? usage?['input_tokens'],
        ),
        outputTokens: _integer(
          usage?['completion_tokens'] ?? usage?['output_tokens'],
        ),
        totalTokens: _integer(usage?['total_tokens']),
      );
    } on PreorderAnalysisRequestException {
      rethrow;
    } on AiAuthenticationException catch (error) {
      throw PreorderAnalysisRequestException(error.message);
    } on TimeoutException {
      throw const PreorderAnalysisRequestException('AI 分析超时，请稍后重试');
    } on SocketException {
      throw const PreorderAnalysisRequestException('无法连接 AI 分析服务，请检查网络');
    } on HttpException {
      throw const PreorderAnalysisRequestException('AI 分析请求失败，请稍后重试');
    } on FormatException {
      throw const PreorderAnalysisRequestException('AI 分析服务返回格式错误');
    }
  }

  static Map<String, Object?> _preorderSummary(PreorderItem item) => {
    'name': item.name,
    'brand': item.brand,
    'category': item.category,
    'price': item.price,
    'material': item.material,
    'size': item.size,
    'clothingLength': item.clothingLength,
    'shoulderWidth': item.shoulderWidth,
    'chestCircumference': item.chestCircumference,
    'sleeveLength': item.sleeveLength,
    'waistCircumference': item.waistCircumference,
    'hipCircumference': item.hipCircumference,
    'trouserLength': item.trouserLength,
    'productUrl': item.productUrl,
    'description': item.description,
    'notes': item.notes,
  };

  static Uri? _parseEndpoint(String value, bool allowInsecureHttp) {
    final uri = Uri.tryParse(value.trim());
    if (uri == null ||
        !uri.hasScheme ||
        !uri.hasAuthority ||
        (uri.scheme != 'https' &&
            !(allowInsecureHttp && uri.scheme == 'http'))) {
      return null;
    }
    return uri;
  }

  static String? _normalize(String? value) {
    final normalized = value?.trim() ?? '';
    return normalized.isEmpty ? null : normalized;
  }

  static String? _string(Object? value) =>
      value is String ? _normalize(value) : null;

  static Map<String, Object?> _decodeObject(String source) {
    final decoded = jsonDecode(source);
    if (decoded is! Map) {
      throw const FormatException('Expected a JSON object');
    }
    return decoded.map((key, value) => MapEntry(key.toString(), value));
  }

  static Map<String, Object?>? _optionalObjectMap(Object? value) {
    if (value is! Map) {
      return null;
    }
    return value.map((key, item) => MapEntry(key.toString(), item));
  }

  static int? _integer(Object? value) => value is num ? value.toInt() : null;

  static String _safeErrorMessage(
    Map<String, Object?> response,
    int statusCode,
  ) {
    final message = response['message'];
    if (message is String && message.trim().isNotEmpty) {
      return message.trim();
    }
    if (statusCode == HttpStatus.unauthorized ||
        statusCode == HttpStatus.forbidden) {
      return 'AI 分析服务鉴权失败';
    }
    if (statusCode == HttpStatus.tooManyRequests) {
      return 'AI 分析请求过于频繁，请稍后重试';
    }
    return 'AI 分析服务异常（$statusCode）';
  }
}

class PreorderAnalysisUnavailableException implements Exception {
  const PreorderAnalysisUnavailableException([this.message = 'AI 分析服务尚未配置']);

  final String message;

  @override
  String toString() => message;
}

class PreorderAnalysisRequestException implements Exception {
  const PreorderAnalysisRequestException(this.message);

  final String message;

  @override
  String toString() => message;
}
