import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeatlas/features/wardrobe/data/clothing_image_parameter_service.dart';

class _TlsClient extends Fake implements HttpClient {
  @override
  Future<HttpClientRequest> postUrl(Uri url) async =>
      throw const HandshakeException('synthetic-private-password-and-token');
}

class _LateRequest extends Fake implements HttpClientRequest {
  bool aborted = false;
  @override
  void abort([Object? exception, StackTrace? stackTrace]) {
    aborted = true;
  }
}

class _LateClient extends Fake implements HttpClient {
  final request = _LateRequest();
  @override
  Future<HttpClientRequest> postUrl(Uri url) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    return request;
  }
}

Future<ClothingImageParameterRequestException> probe(
  Future<void> Function(HttpRequest request) handler, {
  Duration timeout = const Duration(seconds: 3),
  Duration authDelay = Duration.zero,
  HttpClient? client,
  Future<String> Function()? token,
}) async {
  final dir = await Directory.systemTemp.createTemp(
    'lifeatlas-diagnostic-test-',
  );
  final image = File('${dir.path}/private-image.jpg');
  await image.writeAsBytes([255, 216, 255, 217]);
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  server.listen((r) async {
    try {
      await handler(r);
    } catch (_) {
      /* Client deadline may cancel a synthetic response. */
    }
  });
  final service = DoubaoProxyClothingImageParameterService(
    proxyUrl: 'http://127.0.0.1:${server.port}/v1/wardrobe/analyze',
    allowInsecureHttp: true,
    httpClient: client,
    timeout: timeout,
    accessTokenProvider:
        token ??
        () async {
          await Future<void>.delayed(authDelay);
          return 'synthetic-secret-token';
        },
  );
  try {
    await service.analyze(image.path);
    fail('Expected recognition failure');
  } on ClothingImageParameterRequestException catch (e) {
    return e;
  } finally {
    await server.close(force: true);
    final root = await Directory.systemTemp.resolveSymbolicLinks();
    final resolved = await dir.resolveSymbolicLinks();
    if (!resolved.startsWith(
      '$root${Platform.pathSeparator}lifeatlas-diagnostic-test-',
    )) {
      throw StateError('Unexpected test directory');
    }
    await dir.delete(recursive: true);
  }
}

void main() {
  test(
    'connection completing after deadline is aborted instead of sending an image',
    () async {
      final client = _LateClient();
      final e = await probe(
        (r) async {},
        client: client,
        timeout: const Duration(milliseconds: 150),
      );
      expect(e.diagnostic!.code, 'timeout');
      await Future<void>.delayed(const Duration(milliseconds: 350));
      expect(client.request.aborted, true);
    },
  );
  test(
    'real connection interruption has its own classification without exposing image path or token',
    () async {
      final e = await probe((r) async {
        await r.drain<void>();
        final s = await r.response.detachSocket(writeHeaders: false);
        s.destroy();
      });
      expect(e.message, '识别连接已中断，请稍后重试');
      expect(e.diagnostic!.code, 'connection_interrupted');
      expect(e.diagnostic!.phase, '上传图片并等待响应');
      expect(e.diagnostic!.elapsedMs, greaterThanOrEqualTo(0));
      expect(e.diagnostic!.text, isNot(contains('private-image')));
      expect(e.diagnostic!.text, isNot(contains('synthetic-secret-token')));
    },
  );

  test(
    'TLS failure retains a safe exception type without its private message',
    () async {
      final e = await probe((r) async {}, client: _TlsClient());
      expect(e.diagnostic!.code, 'tls_connection');
      expect(e.diagnostic!.exceptionType, 'HandshakeException');
      expect(e.diagnostic!.text, isNot(contains('synthetic-private')));
      expect(e.message, contains('安全连接失败'));
    },
  );

  test(
    'HTML gateway errors retain status; authentication and rate limits remain actionable',
    () async {
      for (final status in [401, 403, 429, 502, 503, 524]) {
        final e = await probe((r) async {
          await r.drain<void>();
          r.response.statusCode = status;
          r.response.headers.set('cf-ray', '1234567890abcdef-HKG');
          r.response.write('<html>private-upstream-content</html>');
          await r.response.close();
        });
        expect(e.diagnostic!.httpStatus, status);
        expect(e.diagnostic!.rayId, '1234567890abcdef-HKG');
        expect(e.diagnostic!.text, isNot(contains('private-upstream-content')));
        if (status == 524) {
          expect(e.message, 'AI识别超时，请稍后重试');
          expect(e.diagnostic!.code, 'gateway_timeout');
        } else if (status == 401 || status == 403) {
          expect(e.message, contains('重新登录'));
        } else if (status == 429) {
          expect(e.message, contains('频繁'));
        } else {
          expect(e.message, contains('$status'));
        }
      }
    },
  );

  test(
    'invalid success data is distinguished from an invalid normalized result',
    () async {
      final invalid = await probe((r) async {
        await r.drain<void>();
        r.response.write('private-not-json');
        await r.response.close();
      });
      expect(invalid.diagnostic!.code, 'invalid_response');
      expect(invalid.diagnostic!.httpStatus, 200);
      expect(invalid.diagnostic!.text, isNot(contains('private-not-json')));
      final result = await probe((r) async {
        await r.drain<void>();
        r.response.write(
          jsonEncode({
            'result': {
              'seasonTags': ['无效季节'],
            },
          }),
        );
        await r.response.close();
      });
      expect(result.diagnostic!.code, 'invalid_result');
    },
  );

  test(
    'one deadline covers authentication, response headers and body without a repeated paid request',
    () async {
      var calls = 0;
      final e = await probe(
        (r) async {
          calls++;
          await r.drain<void>();
          await Future<void>.delayed(const Duration(milliseconds: 80));
          r.response.bufferOutput = false;
          r.response.write('{"result":');
          await r.response.flush();
          await Future<void>.delayed(const Duration(milliseconds: 120));
          r.response.write('{"measurements":{}}}');
          await r.response.close();
        },
        authDelay: const Duration(milliseconds: 80),
        timeout: const Duration(milliseconds: 240),
      );
      expect(e.diagnostic!.code, 'timeout');
      expect(calls, 1);
      expect(e.diagnostic!.elapsedMs, lessThan(1500));
    },
  );

  test(
    'redirect is not followed and unsafe or duplicated trace headers are ignored',
    () async {
      var calls = 0;
      final e = await probe((r) async {
        calls++;
        await r.drain<void>();
        r.response.statusCode = 302;
        r.response.headers.set(
          HttpHeaders.locationHeader,
          '/unexpected-second-request',
        );
        r.response.headers.add('cf-ray', 'do-not-copy-private-token');
        r.response.headers.add('cf-ray', '1234567890abcdef-HKG');
        await r.response.close();
      });
      expect(calls, 1);
      expect(e.diagnostic!.httpStatus, 302);
      expect(e.diagnostic!.rayId, isNull);
    },
  );

  test(
    'unexpected login storage failure records the phase but not credentials',
    () async {
      final e = await probe(
        (r) async {},
        token: () async => throw StateError('private-account-password'),
      );
      expect(e.diagnostic!.phase, '读取登录状态');
      expect(e.diagnostic!.code, 'unexpected');
      expect(e.message, isNot(contains('private-account-password')));
      expect(e.diagnostic!.text, isNot(contains('private-account-password')));
    },
  );
}
