import 'dart:async';
import 'dart:convert';
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
    this.timeout = const Duration(seconds: 60),
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
    final endpoint = _endpoint;
    if (endpoint == null) {
      throw const ClothingImageParameterUnavailableException();
    }

    final file = File(imagePath);
    if (!await file.exists()) {
      throw const ClothingImageParameterRequestException('找不到所选图片，请重新选择');
    }
    final byteLength = await file.length();
    if (byteLength <= 0) {
      throw const ClothingImageParameterRequestException('所选图片为空，请重新选择');
    }
    if (byteLength > _maximumImageBytes) {
      throw const ClothingImageParameterRequestException('图片不能超过 10 MB');
    }

    final mimeType = _mimeTypeForPath(imagePath);
    if (mimeType == null) {
      throw const ClothingImageParameterRequestException(
        '仅支持 JPG、PNG、WebP 或 GIF 图片',
      );
    }

    try {
      final tokenProvider = accessTokenProvider;
      if (tokenProvider == null) {
        throw const AiAuthenticationException('请先在“我的－AI 服务账号”中登录');
      }
      final accessToken = await tokenProvider();
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
          'imageBase64': base64Encode(await file.readAsBytes()),
        }),
      );

      final response = await request.close().timeout(timeout);
      final responseText = await utf8.decoder
          .bind(response)
          .join()
          .timeout(timeout);
      final decoded = _decodeObject(responseText);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw ClothingImageParameterRequestException(
          _safeErrorMessage(decoded, response.statusCode),
        );
      }

      final result = _objectMap(decoded['result'] ?? decoded);
      if (result.isEmpty) {
        throw const ClothingImageParameterRequestException('识别服务返回了无效结果');
      }
      return ClothingImageParameters.fromJson(result);
    } on ClothingImageParameterRequestException {
      rethrow;
    } on AiAuthenticationException catch (error) {
      throw ClothingImageParameterRequestException(error.message);
    } on TimeoutException {
      throw const ClothingImageParameterRequestException('图片识别超时，请稍后重试');
    } on SocketException {
      throw const ClothingImageParameterRequestException('无法连接图片识别服务，请检查网络');
    } on HttpException {
      throw const ClothingImageParameterRequestException('图片识别请求失败，请稍后重试');
    } on FormatException {
      throw const ClothingImageParameterRequestException('识别服务返回格式错误');
    }
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
