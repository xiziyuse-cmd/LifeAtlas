import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

class CommunityImages {
  static Future<String> cache(String url, String id, int revision) async {
    if (url.isEmpty) {
      return '';
    }
    final uri = Uri.parse(url);
    if (uri.scheme != 'https' ||
        uri.host != 'lifeatlas-updates.xiziyuse.workers.dev' ||
        uri.path != '/v1/app/image' ||
        !RegExp(r'^[a-f0-9-]{36}$').hasMatch(id)) {
      throw const FormatException('公共图片地址无效');
    }
    final dir = Directory(
      '${(await getApplicationSupportDirectory()).path}/public-recipes',
    );
    await dir.create(recursive: true);
    final file = File('${dir.path}/$id-$revision.png');
    if (await file.exists()) {
      return file.path;
    }
    final client = HttpClient()..userAgent = 'LifeAtlas/2.3';
    try {
      final request = await client
          .getUrl(uri)
          .timeout(const Duration(seconds: 15));
      request.followRedirects = false;
      final response = await request.close().timeout(
        const Duration(seconds: 15),
      );
      if (response.statusCode != 200) {
        throw StateError('公共图片下载失败');
      }
      final bytes = <int>[];
      await for (final chunk in response.timeout(const Duration(seconds: 15))) {
        bytes.addAll(chunk);
        if (bytes.length > 520000) {
          throw const FormatException('公共图片过大');
        }
      }
      if (bytes.length < 8 ||
          bytes.take(8).toList().join(',') != '137,80,78,71,13,10,26,10') {
        throw const FormatException('公共图片格式无效');
      }
      await file.writeAsBytes(bytes, flush: true);
      return file.path;
    } finally {
      client.close();
    }
  }

  static Future<String> personalCopy(String image) async {
    if (image.isEmpty) {
      return '';
    }
    final dir = Directory(
      '${(await getApplicationSupportDirectory()).path}/recipe-copies',
    );
    await dir.create(recursive: true);
    final file = File(
      '${dir.path}/${DateTime.now().microsecondsSinceEpoch}.png',
    );
    if (image.startsWith('assets/')) {
      final data = await rootBundle.load(image);
      await file.writeAsBytes(
        data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
      );
    } else {
      await File(image).copy(file.path);
    }
    return file.path;
  }
}
