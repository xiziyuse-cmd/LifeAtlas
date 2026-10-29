import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

abstract interface class AiTokenStore {
  Future<String?> read();

  Future<void> write(String value);

  Future<void> clear();
}

class SecureAiTokenStore implements AiTokenStore {
  SecureAiTokenStore({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  static const _storageKey = 'lifeatlas_ai_session_v1';

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read() => _storage.read(key: _storageKey);

  @override
  Future<void> write(String value) =>
      _storage.write(key: _storageKey, value: value);

  @override
  Future<void> clear() => _storage.delete(key: _storageKey);
}

class AiAuthSession extends ChangeNotifier {
  AiAuthSession({
    required String authBaseUrl,
    AiTokenStore? tokenStore,
    bool allowInsecureHttp = false,
    this.timeout = const Duration(seconds: 30),
    HttpClient? httpClient,
  }) : _authBaseUri = _parseBaseUri(authBaseUrl, allowInsecureHttp),
       _tokenStore = tokenStore ?? SecureAiTokenStore(),
       _httpClient = httpClient ?? HttpClient();

  final Uri? _authBaseUri;
  final AiTokenStore _tokenStore;
  final HttpClient _httpClient;
  final Duration timeout;

  _AiTokenSet? _tokens;
  Future<_AiTokenSet>? _refreshOperation;
  bool _initialized = false;
  bool _busy = false;
  String? _lastError;

  bool get isConfigured => _authBaseUri != null;
  bool get initialized => _initialized;
  bool get busy => _busy;
  String? get lastError => _lastError;
  String? get username => _tokens?.username;

  bool get isAuthenticated {
    final tokens = _tokens;
    return tokens != null &&
        tokens.refreshTokenExpiresAt.isAfter(DateTime.now());
  }

  Future<void> initialize() async {
    if (_initialized) return;
    try {
      final encoded = await _tokenStore.read();
      if (encoded != null) {
        final tokens = _AiTokenSet.tryDecode(encoded);
        if (tokens != null &&
            tokens.refreshTokenExpiresAt.isAfter(DateTime.now())) {
          _tokens = tokens;
        } else {
          await _tokenStore.clear();
        }
      }
    } catch (_) {
      await _tokenStore.clear();
    }
    _initialized = true;
    notifyListeners();
  }

  Future<void> login({
    required String username,
    required String password,
  }) async {
    final normalizedUsername = username.trim();
    if (normalizedUsername.isEmpty || password.isEmpty) {
      throw const AiAuthenticationException('请输入账号和密码');
    }
    _setBusy(true);
    try {
      final tokens = await _requestTokenPair(
        path: 'login',
        body: {'username': normalizedUsername, 'password': password},
      );
      await _saveTokens(tokens);
      _lastError = null;
    } on AiAuthenticationException catch (error) {
      _lastError = error.message;
      rethrow;
    } finally {
      _setBusy(false);
    }
  }

  Future<String> validAccessToken() async {
    if (!isConfigured) {
      throw const AiAuthenticationException('AI 账号服务尚未配置');
    }
    final tokens = _tokens;
    if (tokens == null ||
        !tokens.refreshTokenExpiresAt.isAfter(DateTime.now())) {
      await _clearSession();
      throw const AiAuthenticationException('请先在“我的－AI 服务账号”中登录');
    }
    if (tokens.accessTokenExpiresAt.isAfter(
      DateTime.now().add(const Duration(minutes: 1)),
    )) {
      return tokens.accessToken;
    }

    final operation = _refreshOperation ??= _refreshTokens(tokens.refreshToken);
    try {
      return (await operation).accessToken;
    } finally {
      if (identical(_refreshOperation, operation)) {
        _refreshOperation = null;
      }
    }
  }

  Future<void> logout() async {
    _refreshOperation = null;
    await _clearSession();
    _lastError = null;
    notifyListeners();
  }

  Future<_AiTokenSet> _refreshTokens(String refreshToken) async {
    try {
      final tokens = await _requestTokenPair(
        path: 'refresh',
        body: {'refreshToken': refreshToken},
      );
      await _saveTokens(tokens);
      return tokens;
    } on AiAuthenticationException {
      await _clearSession();
      notifyListeners();
      rethrow;
    }
  }

  Future<_AiTokenSet> _requestTokenPair({
    required String path,
    required Map<String, Object?> body,
  }) async {
    final baseUri = _authBaseUri;
    if (baseUri == null) {
      throw const AiAuthenticationException('AI 账号服务尚未配置');
    }
    final endpoint = Uri.parse('${baseUri.toString()}/$path');
    try {
      final request = await _httpClient.postUrl(endpoint).timeout(timeout);
      request.headers.contentType = ContentType.json;
      request.headers.set(HttpHeaders.acceptHeader, ContentType.json.mimeType);
      request.write(jsonEncode(body));
      final response = await request.close().timeout(timeout);
      final responseText = await utf8.decoder
          .bind(response)
          .join()
          .timeout(timeout);
      final decoded = _decodeObject(responseText);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw AiAuthenticationException(
          _safeErrorMessage(decoded, response.statusCode),
        );
      }
      return _AiTokenSet.fromResponse(decoded);
    } on AiAuthenticationException {
      rethrow;
    } on TimeoutException {
      throw const AiAuthenticationException('AI 账号服务响应超时，请稍后重试');
    } on SocketException {
      throw const AiAuthenticationException('无法连接 AI 账号服务，请检查网络');
    } on HttpException {
      throw const AiAuthenticationException('AI 账号请求失败，请稍后重试');
    } on FormatException {
      throw const AiAuthenticationException('AI 账号服务返回格式错误');
    }
  }

  Future<void> _saveTokens(_AiTokenSet tokens) async {
    await _tokenStore.write(tokens.encode());
    _tokens = tokens;
    notifyListeners();
  }

  Future<void> _clearSession() async {
    _tokens = null;
    await _tokenStore.clear();
  }

  void _setBusy(bool value) {
    if (_busy == value) return;
    _busy = value;
    notifyListeners();
  }

  static Uri? _parseBaseUri(String value, bool allowInsecureHttp) {
    final normalized = value.trim().replaceFirst(RegExp(r'/+$'), '');
    final uri = Uri.tryParse(normalized);
    if (uri == null ||
        !uri.hasScheme ||
        !uri.hasAuthority ||
        (uri.scheme != 'https' &&
            !(allowInsecureHttp && uri.scheme == 'http'))) {
      return null;
    }
    return uri;
  }

  static Map<String, Object?> _decodeObject(String source) {
    final decoded = jsonDecode(source);
    if (decoded is! Map) throw const FormatException('Expected JSON object');
    return decoded.map((key, value) => MapEntry(key.toString(), value));
  }

  static String _safeErrorMessage(
    Map<String, Object?> response,
    int statusCode,
  ) {
    final message = response['message'];
    if (message is String && message.trim().isNotEmpty) return message.trim();
    if (statusCode == HttpStatus.unauthorized ||
        statusCode == HttpStatus.forbidden) {
      return '账号或密码错误，或登录状态已经过期';
    }
    if (statusCode == HttpStatus.tooManyRequests) {
      return '登录请求过于频繁，请稍后重试';
    }
    return 'AI 账号服务异常（$statusCode）';
  }
}

class AiAuthenticationException implements Exception {
  const AiAuthenticationException(this.message);

  final String message;

  @override
  String toString() => message;
}

class _AiTokenSet {
  const _AiTokenSet({
    required this.username,
    required this.accessToken,
    required this.refreshToken,
    required this.accessTokenExpiresAt,
    required this.refreshTokenExpiresAt,
  });

  final String username;
  final String accessToken;
  final String refreshToken;
  final DateTime accessTokenExpiresAt;
  final DateTime refreshTokenExpiresAt;

  factory _AiTokenSet.fromResponse(Map<String, Object?> response) {
    final username = _requiredString(response['username']);
    final accessToken = _requiredString(response['accessToken']);
    final refreshToken = _requiredString(response['refreshToken']);
    final accessExpiresAt = _requiredEpoch(response['accessTokenExpiresAt']);
    final refreshExpiresAt = _requiredEpoch(response['refreshTokenExpiresAt']);
    return _AiTokenSet(
      username: username,
      accessToken: accessToken,
      refreshToken: refreshToken,
      accessTokenExpiresAt: accessExpiresAt,
      refreshTokenExpiresAt: refreshExpiresAt,
    );
  }

  static _AiTokenSet? tryDecode(String source) {
    try {
      final decoded = jsonDecode(source);
      if (decoded is! Map) return null;
      return _AiTokenSet.fromResponse(
        decoded.map((key, value) => MapEntry(key.toString(), value)),
      );
    } catch (_) {
      return null;
    }
  }

  String encode() => jsonEncode({
    'username': username,
    'accessToken': accessToken,
    'refreshToken': refreshToken,
    'accessTokenExpiresAt': accessTokenExpiresAt.millisecondsSinceEpoch ~/ 1000,
    'refreshTokenExpiresAt':
        refreshTokenExpiresAt.millisecondsSinceEpoch ~/ 1000,
  });

  static String _requiredString(Object? value) {
    if (value is! String || value.trim().isEmpty) {
      throw const FormatException('Missing token field');
    }
    return value.trim();
  }

  static DateTime _requiredEpoch(Object? value) {
    if (value is! num || value <= 0) {
      throw const FormatException('Missing token expiration');
    }
    return DateTime.fromMillisecondsSinceEpoch(
      value.toInt() * 1000,
      isUtc: true,
    );
  }
}
