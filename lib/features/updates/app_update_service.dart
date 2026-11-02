import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

class AppRelease {
  const AppRelease({
    required this.version,
    required this.build,
    required this.notes,
    required this.size,
    required this.sha256,
    required this.minSdk,
    required this.url,
  });
  final String version, notes, sha256;
  final int build, size, minSdk;
  final Uri url;
  static AppRelease? parse(Map<String, dynamic> data, Uri endpoint) {
    final value = data['release'];
    if (value == null) {
      return null;
    }
    if (value is! Map<String, dynamic>) {
      throw const FormatException('更新信息格式错误');
    }
    final url = Uri.tryParse(
      value['url'] is String ? value['url'] as String : '',
    );
    if (value['packageName'] != 'com.example.lifeatlas' ||
        value['version'] is! String ||
        !RegExp(
          r'^\d{1,4}\.\d{1,4}\.\d{1,4}$',
        ).hasMatch(value['version'] as String) ||
        value['build'] is! int ||
        (value['build'] as int) < 1 ||
        value['notes'] is! String ||
        (value['notes'] as String).length > 6000 ||
        value['size'] is! int ||
        (value['size'] as int) < 1024 ||
        (value['size'] as int) > 160 * 1024 * 1024 ||
        value['minSdk'] is! int ||
        (value['minSdk'] as int) < 24 ||
        value['sha256'] is! String ||
        !RegExp(r'^[a-f0-9]{64}$').hasMatch(value['sha256'] as String) ||
        url == null ||
        url.scheme != 'https' ||
        url.origin != endpoint.origin ||
        url.path != endpoint.path ||
        url.userInfo.isNotEmpty ||
        url.fragment.isNotEmpty ||
        url.queryParameters['download'] != '1') {
      throw const FormatException('更新信息不完整或下载地址无效');
    }
    return AppRelease(
      version: value['version'] as String,
      build: value['build'] as int,
      notes: value['notes'] as String,
      size: value['size'] as int,
      sha256: value['sha256'] as String,
      minSdk: value['minSdk'] as int,
      url: url,
    );
  }

  bool isNewerThan(int currentBuild) => build > currentBuild;
}

class UpdateCancelled implements Exception {
  const UpdateCancelled();
}

class AppUpdateService {
  AppUpdateService({
    HttpClient? client,
    Future<Directory> Function()? temporaryDirectory,
  }) : _client = client ?? HttpClient(),
       _temporaryDirectory = temporaryDirectory ?? getTemporaryDirectory;
  final HttpClient _client;
  final Future<Directory> Function() _temporaryDirectory;
  static const _channel = MethodChannel('lifeatlas/updates');
  static final endpoint = Uri.parse(
    const String.fromEnvironment(
      'LIFEATLAS_UPDATE_URL',
      defaultValue:
          'https://lifeatlas-updates.xiziyuse.workers.dev/v1/update/latest',
    ),
  );
  bool _cancelled = false;
  HttpClientRequest? _request;
  static bool get supported => Platform.isAndroid;
  Future<Map<String, dynamic>> deviceInfo() async => Map<String, dynamic>.from(
    (await _channel.invokeMethod<Map<dynamic, dynamic>>('deviceInfo'))!,
  );
  Future<AppRelease?> check() async {
    if (endpoint.scheme != 'https' ||
        endpoint.host.isEmpty ||
        endpoint.userInfo.isNotEmpty) {
      throw StateError('更新服务地址无效');
    }
    return (() async {
      final request = await _client.getUrl(endpoint);
      request.followRedirects = false;
      final response = await request.close();
      if (response.statusCode != 200) {
        await response.drain<void>();
        throw StateError('更新服务暂不可用，请稍后重试');
      }
      final bytes = <int>[];
      await for (final chunk in response) {
        bytes.addAll(chunk);
        if (bytes.length > 32768) {
          throw const FormatException('更新信息过大');
        }
      }
      final data = jsonDecode(utf8.decode(bytes));
      if (data is! Map<String, dynamic>) {
        throw const FormatException('更新信息格式错误');
      }
      return AppRelease.parse(data, endpoint);
    })().timeout(const Duration(seconds: 20));
  }

  void cancel() {
    _cancelled = true;
    _request?.abort(const UpdateCancelled());
  }

  void close() {
    cancel();
    _client.close(force: true);
  }

  Future<File> download(
    AppRelease release,
    void Function(int, int) onProgress,
  ) async {
    _cancelled = false;
    final dir = Directory('${(await _temporaryDirectory()).path}/updates');
    await dir.create(recursive: true);
    // Keep at most one installer. A cancelled or corrupt download cannot be installed.
    for (final entry in dir.listSync()) {
      if (entry is File) {
        await entry.delete();
      }
    }
    final target = File('${dir.path}/update-${release.build}.apk');
    final partial = File('${target.path}.part');
    IOSink? sink;
    try {
      final request = await _client
          .getUrl(release.url)
          .timeout(const Duration(seconds: 20));
      _request = request;
      request.followRedirects = false;
      if (_cancelled) {
        throw const UpdateCancelled();
      }
      final response = await request.close().timeout(
        const Duration(seconds: 30),
      );
      if (response.statusCode != 200) {
        throw StateError('下载失败，请重新检查更新');
      }
      if (response.contentLength != -1 &&
          response.contentLength != release.size) {
        throw StateError('安装包大小与版本信息不一致');
      }
      sink = partial.openWrite();
      var received = 0;
      await for (final chunk in response.timeout(const Duration(seconds: 30))) {
        if (_cancelled) {
          throw const UpdateCancelled();
        }
        received += chunk.length;
        if (received > release.size) {
          throw StateError('安装包大小不正确');
        }
        sink.add(chunk);
        await sink.flush();
        onProgress(received, release.size);
      }
      await sink.close();
      sink = null;
      if (_cancelled) {
        throw const UpdateCancelled();
      }
      if (received != release.size) {
        throw StateError('安装包下载不完整');
      }
      await partial.rename(target.path);
      await _verify(target, release);
      return target;
    } catch (_) {
      if (sink != null) {
        await sink.close();
      }
      if (await partial.exists()) {
        await partial.delete();
      }
      if (await target.exists()) {
        await target.delete();
      }
      rethrow;
    } finally {
      _request = null;
    }
  }

  Map<String, dynamic> _arguments(File file, AppRelease release) => {
    'path': file.path,
    'sha256': release.sha256,
    'size': release.size,
    'build': release.build,
    'version': release.version,
  };
  Future<void> _verify(File file, AppRelease release) async {
    await _channel.invokeMethod<void>('verifyApk', _arguments(file, release));
  }

  Future<String> install(File file, AppRelease release) async =>
      await _channel.invokeMethod<String>(
        'install',
        _arguments(file, release),
      ) ??
      'opened';
}
