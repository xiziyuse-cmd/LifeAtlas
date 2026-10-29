import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeatlas/features/updates/app_update_service.dart';

void main() {
  final endpoint = Uri.parse(
    'https://lifeatlas-updates.xiziyuse.workers.dev/v1/update/latest',
  );
  Map<String, dynamic> manifest() => {
    'release': {
      'version': '2.1.0',
      'build': 28,
      'notes': '更新说明',
      'size': 1024,
      'sha256': 'a' * 64,
      'minSdk': 24,
      'packageName': 'com.example.lifeatlas',
      'url': '$endpoint?download=1&id=example',
    },
  };
  test(
    'uses numeric build ordering and accepts only the expected package and HTTPS origin',
    () {
      final release = AppRelease.parse(manifest(), endpoint)!;
      expect(release.isNewerThan(27), isTrue);
      expect(release.isNewerThan(28), isFalse);
      expect(release.isNewerThan(100), isFalse);
      for (final patch in [
        {'packageName': 'evil.app'},
        {'url': 'https://other.test/v1/update/latest?download=1'},
        {
          'url':
              'http://lifeatlas-updates.xiziyuse.workers.dev/v1/update/latest?download=1',
        },
        {'sha256': 'bad'},
        {'size': 999999999},
      ]) {
        final input = manifest();
        (input['release'] as Map).addAll(patch);
        expect(() => AppRelease.parse(input, endpoint), throwsFormatException);
      }
    },
  );
  test(
    'no active release is a valid empty response and malformed metadata is rejected',
    () {
      expect(AppRelease.parse({'release': null}, endpoint), isNull);
      expect(
        () => AppRelease.parse({'release': []}, endpoint),
        throwsFormatException,
      );
    },
  );
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('lifeatlas/updates');
  test(
    'download length and native verification failures remove every installer candidate',
    () async {
      final dir = await Directory.systemTemp.createTemp(
        'lifeatlas-update-test',
      );
      addTearDown(() => dir.delete(recursive: true));
      final release = AppRelease.parse(manifest(), endpoint)!;
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
      var verified = 0;
      messenger.setMockMethodCallHandler(channel, (call) async {
        verified++;
        throw PlatformException(code: 'UPDATE_INVALID', message: '签名不同');
      });
      final service = AppUpdateService(
        client: _Client([List.filled(512, 0)], 512),
        temporaryDirectory: () async => dir,
      );
      await expectLater(service.download(release, (_, _) {}), throwsStateError);
      expect(verified, 0);
      final service2 = AppUpdateService(
        client: _Client([List.filled(1024, 0)], 1024),
        temporaryDirectory: () async => dir,
      );
      await expectLater(
        service2.download(release, (_, _) {}),
        throwsA(isA<PlatformException>()),
      );
      expect(verified, 1);
      expect(Directory('${dir.path}/updates').listSync(), isEmpty);
      service.close();
      service2.close();
    },
  );
  test(
    'verified download is retained and cancellation never leaves a partial installer',
    () async {
      final dir = await Directory.systemTemp.createTemp(
        'lifeatlas-update-test',
      );
      addTearDown(() => dir.delete(recursive: true));
      final release = AppRelease.parse(manifest(), endpoint)!;
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(channel, (call) async {
        expect(call.method, 'verifyApk');
        expect((call.arguments as Map)['sha256'], release.sha256);
        return null;
      });
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
      final service = AppUpdateService(
        client: _Client([List.filled(1024, 0)], 1024),
        temporaryDirectory: () async => dir,
      );
      final file = await service.download(release, (_, _) {});
      expect(await file.length(), 1024);
      service.close();
      final service2 = AppUpdateService(
        client: _Client([List.filled(512, 0), List.filled(512, 0)], 1024),
        temporaryDirectory: () async => dir,
      );
      await expectLater(
        service2.download(release, (_, _) => service2.cancel()),
        throwsA(isA<UpdateCancelled>()),
      );
      expect(Directory('${dir.path}/updates').listSync(), isEmpty);
      service2.close();
    },
  );
}

class _Client extends Fake implements HttpClient {
  _Client(this.chunks, this.length);
  final List<List<int>> chunks;
  final int length;
  @override
  Future<HttpClientRequest> getUrl(Uri url) async => _Request(chunks, length);
  @override
  void close({bool force = false}) {}
}

class _Request extends Fake implements HttpClientRequest {
  _Request(this.chunks, this.length);
  final List<List<int>> chunks;
  final int length;
  @override
  bool followRedirects = true;
  @override
  Future<HttpClientResponse> close() async => _Response(chunks, length);
  @override
  void abort([Object? exception, StackTrace? stackTrace]) {}
}

class _Response extends Stream<List<int>> implements HttpClientResponse {
  _Response(this.chunks, this.contentLength);
  final List<List<int>> chunks;
  @override
  final int contentLength;
  @override
  int get statusCode => 200;
  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int>)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) => Stream.fromIterable(chunks).listen(
    onData,
    onError: onError,
    onDone: onDone,
    cancelOnError: cancelOnError,
  );
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
