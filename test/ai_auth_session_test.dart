import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lifeatlas/core/auth/ai_auth_session.dart';

void main() {
  test('login stores tokens and logout clears them', () async {
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final store = _MemoryAiTokenStore();
    server.listen((request) async {
      expect(request.uri.path, '/v1/auth/login');
      final body = jsonDecode(await utf8.decoder.bind(request).join()) as Map;
      expect(body['username'], 'lifeatlas-user');
      expect(body['password'], 'private-password');
      request.response.headers.contentType = ContentType.json;
      request.response.write(
        jsonEncode({
          'username': 'lifeatlas-user',
          'accessToken': 'access-token',
          'refreshToken': 'refresh-token',
          'accessTokenExpiresAt': now + 900,
          'refreshTokenExpiresAt': now + 86400,
        }),
      );
      await request.response.close();
    });

    final session = AiAuthSession(
      authBaseUrl:
          'http://${InternetAddress.loopbackIPv4.address}:${server.port}/v1/auth',
      tokenStore: store,
      allowInsecureHttp: true,
    );
    addTearDown(() async {
      session.dispose();
      await server.close(force: true);
    });

    await session.initialize();
    expect(session.isAuthenticated, isFalse);
    await session.login(
      username: 'lifeatlas-user',
      password: 'private-password',
    );

    expect(session.isAuthenticated, isTrue);
    expect(session.username, 'lifeatlas-user');
    expect(await session.validAccessToken(), 'access-token');
    expect(store.value, isNotNull);

    await session.logout();
    expect(session.isAuthenticated, isFalse);
    expect(store.value, isNull);
  });

  test('expired access token refreshes once and persists the new pair', () async {
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final store = _MemoryAiTokenStore(
      jsonEncode({
        'username': 'lifeatlas-user',
        'accessToken': 'expired-access-token',
        'refreshToken': 'original-refresh-token',
        'accessTokenExpiresAt': now - 1,
        'refreshTokenExpiresAt': now + 86400,
      }),
    );
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    var refreshCount = 0;
    server.listen((request) async {
      expect(request.uri.path, '/v1/auth/refresh');
      final body = jsonDecode(await utf8.decoder.bind(request).join()) as Map;
      expect(body['refreshToken'], 'original-refresh-token');
      refreshCount += 1;
      request.response.headers.contentType = ContentType.json;
      request.response.write(
        jsonEncode({
          'username': 'lifeatlas-user',
          'accessToken': 'new-access-token',
          'refreshToken': 'new-refresh-token',
          'accessTokenExpiresAt': now + 900,
          'refreshTokenExpiresAt': now + 86400,
        }),
      );
      await request.response.close();
    });

    final session = AiAuthSession(
      authBaseUrl:
          'http://${InternetAddress.loopbackIPv4.address}:${server.port}/v1/auth',
      tokenStore: store,
      allowInsecureHttp: true,
    );
    addTearDown(() async {
      session.dispose();
      await server.close(force: true);
    });
    await session.initialize();

    final results = await Future.wait([
      session.validAccessToken(),
      session.validAccessToken(),
    ]);

    expect(results, everyElement('new-access-token'));
    expect(refreshCount, 1);
    expect(store.value, contains('new-refresh-token'));
  });

  test('invalid auth URL remains unconfigured', () {
    final session = AiAuthSession(
      authBaseUrl: '',
      tokenStore: _MemoryAiTokenStore(),
    );
    addTearDown(session.dispose);

    expect(session.isConfigured, isFalse);
  });
}

class _MemoryAiTokenStore implements AiTokenStore {
  _MemoryAiTokenStore([this.value]);

  String? value;

  @override
  Future<void> clear() async => value = null;

  @override
  Future<String?> read() async => value;

  @override
  Future<void> write(String value) async => this.value = value;
}
