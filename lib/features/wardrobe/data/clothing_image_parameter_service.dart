import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';

import '../../../core/auth/ai_auth_session.dart';
import '../domain/models/clothing_image_parameters.dart';

/// Extracts editable clothing suggestions from a product image or screenshot.
abstract interface class ClothingImageParameterService {
  bool get isConfigured;

  Future<ClothingImageParameters> analyze(String imagePath);
}

class UnconfiguredClothingImageParameterService
    implements ClothingImageParameterService {
  const UnconfiguredClothingImageParameterService();

  @override
  bool get isConfigured => false;

  @override
  Future<ClothingImageParameters> analyze(String imagePath) async {
    throw const ClothingImageParameterUnavailableException();
  }
}

class DoubaoProxyClothingImageParameterService
    implements ClothingImageParameterService {
  DoubaoProxyClothingImageParameterService({
    required String proxyUrl,
    this.accessTokenProvider,
    bool allowInsecureHttp = false,
    this.timeout = const Duration(seconds: 105),
    HttpClient? httpClient,
  }) : _endpoint = _parseEndpoint(proxyUrl, allowInsecureHttp),
       _httpClient = httpClient ?? HttpClient();

  static const _maximumImageBytes = 10 * 1024 * 1024;

  final Uri? _endpoint;
  final Future<String> Function()? accessTokenProvider;
  final Duration timeout;
  final HttpClient _httpClient;

  @override
  bool get isConfigured => _endpoint != null;

  @override
  Future<ClothingImageParameters> analyze(String imagePath) async {
    final stopwatch = Stopwatch()..start();
    var phase = '检查服务配置';
    final endpoint = _endpoint;
    if (endpoint == null) {
      throw const ClothingImageParameterUnavailableException();
    }

    try {
      phase = '读取图片';
      _log('开始读取尺寸图片；供应商 API Key 仅由代理读取，客户端不读取');
      final file = File(imagePath);
      if (!await file.exists()) {
        throw const ClothingImageParameterRequestException('找不到所选图片，请重新选择');
      }
      final byteLength = await file.length();
      _log('尺寸图片大小：$byteLength 字节');
      if (byteLength <= 0) {
        throw const ClothingImageParameterRequestException('所选图片为空，请重新选择');
      }
      if (byteLength > _maximumImageBytes) {
        throw const ClothingImageParameterRequestException(
          '图片超过 10 MB，请裁剪或压缩后重试',
        );
      }

      final mimeType = _mimeTypeForPath(imagePath);
      if (mimeType == null) {
        throw const ClothingImageParameterRequestException(
          '仅支持 JPG、PNG、WebP 或 GIF 图片',
        );
      }
      final imageBytes = await file.readAsBytes();
      _log('图片格式：$mimeType；传输方式：JSON Base64');

      phase = '读取登录状态';
      final tokenProvider = accessTokenProvider;
      if (tokenProvider == null) {
        throw const AiAuthenticationException('请先在“我的－AI 服务账号”中登录');
      }
      final accessToken = await tokenProvider();

      phase = '连接 AI 代理';
      _log(
        '开始请求 AI；模型：Doubao-Seed-2.1-pro（实际版本由代理响应确认）；'
        '代理：${endpoint.origin}${endpoint.path}；请求头：JSON/Accept/Bearer 已设置（不记录令牌）；'
        '开始时间：${DateTime.now().toUtc().toIso8601String()}',
      );
      final request = await _httpClient.postUrl(endpoint).timeout(timeout);
      request.headers.contentType = ContentType.json;
      request.headers.set(HttpHeaders.acceptHeader, ContentType.json.mimeType);
      request.headers.set(
        HttpHeaders.authorizationHeader,
        'Bearer $accessToken',
      );
      request.write(
        jsonEncode({
          'mimeType': mimeType,
          'imageBase64': base64Encode(imageBytes),
        }),
      );

      phase = '等待 AI 响应';
      final response = await request.close().timeout(timeout);
      _log('AI 代理返回状态码：${response.statusCode}');
      phase = '读取 AI 响应';
      final responseText = await utf8.decoder
          .bind(response)
          .join()
          .timeout(timeout);
      phase = '解析 AI 响应';
      final decoded = _decodeObject(responseText);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        final message = _safeErrorMessage(decoded, response.statusCode);
        _log('AI 代理返回错误：$message');
        throw ClothingImageParameterRequestException(message);
      }

      final result = _objectMap(decoded['result'] ?? decoded);
      if (result.isEmpty) {
        throw const ClothingImageParameterRequestException('识别服务返回了无效结果');
      }
      final model = decoded['model'];
      if (model is String && model.trim().isNotEmpty) {
        _log('AI 实际响应模型：${model.trim()}');
      }
      return ClothingImageParameters.fromJson(result);
    } on ClothingImageParameterRequestException catch (error, stackTrace) {
      _logFailure(phase, error, stackTrace);
      rethrow;
    } on AiAuthenticationException catch (error, stackTrace) {
      _logFailure(phase, error, stackTrace);
      throw ClothingImageParameterRequestException(error.message);
    } on TimeoutException catch (error, stackTrace) {
      _logFailure(phase, error, stackTrace);
      throw const ClothingImageParameterRequestException('AI识别超时，请检查网络后重试。');
    } on FileSystemException catch (error, stackTrace) {
      _logFailure(phase, error, stackTrace);
      throw const ClothingImageParameterRequestException('图片读取失败，请重新选择');
    } on SocketException catch (error, stackTrace) {
      _logFailure(phase, error, stackTrace);
      throw const ClothingImageParameterRequestException('网络连接失败，请检查网络后重试');
    } on HttpException catch (error, stackTrace) {
      _logFailure(phase, error, stackTrace);
      throw const ClothingImageParameterRequestException('AI服务请求失败，请稍后重试');
    } on FormatException catch (error, stackTrace) {
      _logFailure(phase, error, stackTrace);
      throw const ClothingImageParameterRequestException('AI返回数据解析失败，请稍后重试');
    } on Object catch (error, stackTrace) {
      _logFailure(phase, error, stackTrace);
      throw const ClothingImageParameterRequestException('AI服务请求失败，请稍后重试');
    } finally {
      stopwatch.stop();
      _log('AI 尺寸识别结束；阶段：$phase；总耗时：${stopwatch.elapsedMilliseconds} ms');
    }
  }

  static void _log(String message) {
    developer.log(message, name: 'lifeatlas.wardrobe.ai');
  }

  static void _logFailure(String phase, Object error, StackTrace stackTrace) {
    developer.log(
      'AI 尺寸识别失败；阶段：$phase',
      name: 'lifeatlas.wardrobe.ai',
      error: error,
      stackTrace: stackTrace,
    );
  }

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

  static String? _mimeTypeForPath(String path) {
    final normalized = path.toLowerCase();
    if (normalized.endsWith('.jpg') || normalized.endsWith('.jpeg')) {
      return 'image/jpeg';
    }
    if (normalized.endsWith('.png')) {
      return 'image/png';
    }
    if (normalized.endsWith('.webp')) {
      return 'image/webp';
    }
    if (normalized.endsWith('.gif')) {
      return 'image/gif';
    }
    return null;
  }

  static Map<String, Object?> _decodeObject(String source) {
    final decoded = jsonDecode(source);
    return _objectMap(decoded);
  }

  static Map<String, Object?> _objectMap(Object? value) {
    if (value is! Map) {
      throw const FormatException('Expected a JSON object');
    }
    return value.map((key, item) => MapEntry(key.toString(), item));
  }

  static String _safeErrorMessage(
    Map<String, Object?> response,
    int statusCode,
  ) {
    final message = response['message'];
    if (statusCode == HttpStatus.gatewayTimeout ||
        (message is String && message.contains('超时'))) {
      return 'AI识别超时，请检查网络后重试。';
    }
    if (message is String && message.trim().isNotEmpty) {
      return message.trim();
    }
    if (statusCode == HttpStatus.unauthorized ||
        statusCode == HttpStatus.forbidden) {
      return '图片识别服务鉴权失败';
    }
    if (statusCode == HttpStatus.tooManyRequests) {
      return '图片识别请求过于频繁，请稍后重试';
    }
    return '图片识别服务异常（$statusCode）';
  }
}

class ClothingImageParameterUnavailableException implements Exception {
  const ClothingImageParameterUnavailableException([
    this.message = '图片参数识别服务尚未配置',
  ]);

  final String message;

  @override
  String toString() => message;
}

class ClothingImageParameterRequestException implements Exception {
  const ClothingImageParameterRequestException(this.message);

  final String message;

  @override
  String toString() => message;
}
