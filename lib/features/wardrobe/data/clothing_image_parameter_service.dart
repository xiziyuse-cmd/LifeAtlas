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
    final startedAt = DateTime.now().toUtc().toIso8601String();
    var phase = '检查服务配置';
    int? status;
    String? ray;
    HttpClientRequest? activeRequest;
    var expired = false, succeeded = false;
    final endpoint = _endpoint;
    if (endpoint == null) {
      throw const ClothingImageParameterUnavailableException();
    }
    Future<T> within<T>(Future<T> Function() action) {
      final remaining = timeout - stopwatch.elapsed;
      if (remaining <= Duration.zero) {
        expired = true;
        activeRequest?.abort();
        throw TimeoutException('Recognition deadline');
      }
      return action().timeout(
        remaining,
        onTimeout: () {
          expired = true;
          activeRequest?.abort();
          throw TimeoutException('Recognition deadline');
        },
      );
    }

    ClothingImageParameterRequestException failure(
      String message,
      String code,
      Object error,
    ) => ClothingImageParameterRequestException(
      message,
      diagnostic: ClothingImageDiagnostic(
        code: code,
        phase: phase,
        elapsedMs: stopwatch.elapsedMilliseconds,
        startedAt: startedAt,
        httpStatus: status,
        exceptionType: error.runtimeType.toString(),
        rayId: ray,
      ),
    );
    try {
      phase = '读取图片';
      final file = File(imagePath);
      if (!await within(file.exists)) {
        throw const ClothingImageParameterRequestException('找不到所选图片，请重新选择');
      }
      final byteLength = await within(file.length);
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
      final imageBytes = await within(file.readAsBytes);
      phase = '读取登录状态';
      final tokenProvider = accessTokenProvider;
      if (tokenProvider == null) {
        throw const AiAuthenticationException('请先在“我的－AI 服务账号”中登录');
      }
      final accessToken = await within(tokenProvider);
      phase = '连接识别服务';
      final request = await within(
        () => _httpClient.postUrl(endpoint).then((request) {
          if (expired) {
            request.abort();
            throw TimeoutException('Late connection');
          }
          activeRequest = request;
          return request;
        }),
      );
      request.followRedirects = false;
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
      phase = '上传图片并等待响应';
      final response = await within(request.close);
      final responseStatus = response.statusCode;
      status = responseStatus;
      final rays = response.headers['cf-ray'];
      final rawRay = rays?.length == 1 ? rays!.single : null;
      if (rawRay != null &&
          RegExp(r'^[a-fA-F0-9]{12,32}(?:-[A-Za-z]{2,5})?$').hasMatch(rawRay)) {
        ray = rawRay;
      }
      phase = '读取响应';
      final bytes = await within(() async {
        final bytes = <int>[];
        await for (final chunk in response) {
          bytes.addAll(chunk);
          if (bytes.length > 2 * 1024 * 1024) {
            throw const FormatException('Response limit');
          }
        }
        return bytes;
      });
      phase = '解析响应';
      Map<String, Object?> decoded;
      try {
        decoded = _decodeObject(utf8.decode(bytes));
      } on FormatException {
        if (responseStatus >= 200 && responseStatus < 300) rethrow;
        decoded = {}; // A gateway HTML error must retain its HTTP status.
      }
      if (responseStatus < 200 || responseStatus >= 300) {
        throw failure(
          _safeErrorMessage(decoded, responseStatus),
          [408, 504, 524].contains(status) ? 'gateway_timeout' : 'http_error',
          const HttpException('HTTP status'),
        );
      }
      final result = _objectMap(decoded['result'] ?? decoded);
      if (result.isEmpty) throw const FormatException('Empty result');
      final parsed = ClothingImageParameters.fromJson(result);
      succeeded = true;
      return parsed;
    } on ClothingImageParameterRequestException catch (error, stack) {
      _logFailure(phase, error, stack);
      if (error.diagnostic != null) rethrow;
      throw failure(error.message, 'input_or_service', error);
    } on AiAuthenticationException catch (error, stack) {
      _logFailure(phase, error, stack);
      throw failure(error.message, 'authentication', error);
    } on TimeoutException catch (error, stack) {
      _logFailure(phase, error, stack);
      throw failure('AI识别超时，请稍后重试', 'timeout', error);
    } on FileSystemException catch (error, stack) {
      _logFailure(phase, error, stack);
      throw failure('图片读取失败，请重新选择', 'image_read', error);
    } on TlsException catch (error, stack) {
      _logFailure(phase, error, stack);
      throw failure('识别服务安全连接失败，请检查网络及手机系统时间', 'tls_connection', error);
    } on SocketException catch (error, stack) {
      _logFailure(phase, error, stack);
      throw failure('网络连接失败，请检查网络后重试', 'network_connection', error);
    } on HttpException catch (error, stack) {
      _logFailure(phase, error, stack);
      throw failure('识别连接已中断，请稍后重试', 'connection_interrupted', error);
    } on FormatException catch (error, stack) {
      _logFailure(phase, error, stack);
      throw failure('识别服务返回了无法解析的数据', 'invalid_response', error);
    } on ArgumentError catch (error, stack) {
      _logFailure(phase, error, stack);
      throw failure('识别结果格式不符合要求，请重试', 'invalid_result', error);
    } on Object catch (error, stack) {
      _logFailure(phase, error, stack);
      throw failure('识别暂未完成，请查看错误详情', 'unexpected', error);
    } finally {
      if (!succeeded) activeRequest?.abort();
      stopwatch.stop();
      _log(
        '尺寸识别结束；阶段：$phase；耗时：${stopwatch.elapsedMilliseconds} ms；HTTP：${status ?? '无'}',
      );
    }
  }

  static void _log(String message) {
    developer.log(message, name: 'lifeatlas.wardrobe.ai');
  }

  static void _logFailure(String phase, Object error, StackTrace stackTrace) {
    developer.log(
      'AI 尺寸识别失败；阶段：$phase',
      name: 'lifeatlas.wardrobe.ai',
      error: error.runtimeType.toString(),
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
    if ([408, 504, 524].contains(statusCode) ||
        (message is String && message.contains('超时'))) {
      return 'AI识别超时，请稍后重试';
    }
    if (message is String && message.trim().isNotEmpty) {
      return message.trim();
    }
    if (statusCode == HttpStatus.unauthorized ||
        statusCode == HttpStatus.forbidden) {
      return '登录状态校验失败，请在“我的－AI 服务账号”中重新登录';
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
  const ClothingImageParameterRequestException(this.message, {this.diagnostic});

  final ClothingImageDiagnostic? diagnostic;

  final String message;

  @override
  String toString() => message;
}

/// Safe, allow-listed metadata only. Never accepts request bodies or raw errors.
class ClothingImageDiagnostic {
  const ClothingImageDiagnostic({
    required this.code,
    required this.phase,
    required this.elapsedMs,
    required this.startedAt,
    this.httpStatus,
    this.exceptionType,
    this.rayId,
  });
  final String code, phase, startedAt;
  final int elapsedMs;
  final int? httpStatus;
  final String? exceptionType, rayId;
  String get text => [
    '功能：衣服尺寸识别',
    '错误类别：$code',
    '失败阶段：$phase',
    '耗时：$elapsedMs ms',
    '开始时间（UTC）：$startedAt',
    if (httpStatus != null) 'HTTP：$httpStatus',
    if (exceptionType != null) '异常类型：$exceptionType',
    if (rayId != null) '请求追踪：$rayId',
  ].join('\n');
}
