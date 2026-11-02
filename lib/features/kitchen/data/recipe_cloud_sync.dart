import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/services.dart';
import '../../../core/network/mobile_api.dart';
import 'kitchen_repository.dart';
import 'community_images.dart';

class RecipeCloudSync {
  RecipeCloudSync({required this.repository, MobileApi? api})
    : api = api ?? MobileApi.shared;
  final KitchenRepository repository;
  final MobileApi api;
  static Future<String>? _running;
  Future<String> synchronize() =>
      _running ??= _sync().whenComplete(() => _running = null);
  Future<String> _sync() async {
    final identity = await api.identity(),
        owner = identity['ownerId'] as String,
        db = await api.database.database;
    await db.transaction((tx) async {
      await tx.update('recipe', {
        'owner_id': owner,
      }, where: "owner_id = '' AND source_type != 'public'");
      final queued = await tx.query(
        'app_settings',
        where: 'setting_key = ?',
        whereArgs: ['recipe_cloud_bootstrap'],
      );
      if (queued.isEmpty) {
        await tx.rawInsert(
          "INSERT OR IGNORE INTO recipe_sync_queue(recipe_id,deleted,version) SELECT id,is_deleted,update_time FROM recipe WHERE source_type != 'public' AND owner_id = ?",
          [owner],
        );
        await tx.insert('app_settings', {
          'setting_key': 'recipe_cloud_bootstrap',
          'setting_value': 'true',
        });
      }
    });
    String? failure;
    for (var pass = 0; pass < 3; pass++) {
      final queue = await db.rawQuery(
        "SELECT q.* FROM recipe_sync_queue q JOIN recipe r ON r.id=q.recipe_id WHERE r.owner_id=? AND r.source_type != 'public' ORDER BY q.version LIMIT 100",
        [owner],
      );
      if (queue.isEmpty) {
        break;
      }
      final recipes = {for (final r in await repository.listRecipes()) r.id: r};
      for (final item in queue) {
        final id = item['recipe_id'] as int;
        try {
          if (item['deleted'] == 1) {
            await api.call('delete', {'recipeId': id});
          } else {
            final recipe = recipes[id];
            if (recipe == null) {
              continue;
            }
            final image = await encodeImage(recipe.image);
            await api.call('upsert', {
              'recipeId': id,
              'recipe': recipe.toMap(),
              'image': image,
            });
          }
          await db.delete(
            'recipe_sync_queue',
            where: 'recipe_id = ? AND version = ?',
            whereArgs: [id, item['version']],
          );
        } catch (e) {
          failure = '个人菜谱待同步：${_message(e)}';
        }
      }
      if (failure != null) {
        break;
      }
    }
    final remaining = await db.rawQuery(
      'SELECT COUNT(*) AS count FROM recipe_sync_queue q JOIN recipe r ON r.id=q.recipe_id WHERE r.owner_id=?',
      [owner],
    );
    final pending = remaining.first['count'] as int;
    if (pending > 0) {
      failure = '还有$pending道个人菜谱待同步${failure == null ? '' : ' · $failure'}';
    }
    try {
      final all = <Map<String, dynamic>>[];
      String? after;
      do {
        final data = await api.call('catalog', {'after': after ?? ''});
        all.addAll(
          (data['recipes'] as List).map(
            (r) => Map<String, dynamic>.from(r as Map),
          ),
        );
        after = data['next'] as String?;
        if (all.length > 5000) {
          throw const FormatException('公共菜谱数量过多');
        }
      } while (after != null);
      for (final item in all) {
        item['image'] = await CommunityImages.cache(
          item['image'] as String,
          item['publicId'] as String,
          item['revision'] as int,
        );
      }
      await repository.applyPublicRecipes(all);
    } catch (e) {
      failure = [?failure, '公共菜谱暂未刷新：${_message(e)}'].join('；');
    }
    return failure ?? '菜谱已同步 · 公共库已更新';
  }

  static String _message(Object e) =>
      e.toString().replaceFirst(RegExp(r'^(Bad state: |Exception: )'), '');
  static Future<String> encodeImage(String path) async {
    if (path.isEmpty) {
      return '';
    }
    // Community images already have a server snapshot. Personal copies retain the visual.
    Uint8List bytes;
    if (path.startsWith('assets/')) {
      bytes = (await rootBundle.load(path)).buffer.asUint8List();
    } else if (path.startsWith(
      'https://lifeatlas-updates.xiziyuse.workers.dev/v1/app/image?',
    )) {
      final client = HttpClient();
      try {
        final request = await client.getUrl(Uri.parse(path));
        request.followRedirects = false;
        final response = await request.close();
        if (response.statusCode != 200) {
          throw StateError('原公共图片已撤下，请重新选择图片');
        }
        final chunks = <int>[];
        await for (final c in response) {
          chunks.addAll(c);
          if (chunks.length > 600000) {
            throw StateError('图片过大');
          }
        }
        bytes = Uint8List.fromList(chunks);
      } finally {
        client.close();
      }
    } else {
      bytes = await File(path).readAsBytes();
    }
    for (final width in [640, 400, 240]) {
      final codec = await ui.instantiateImageCodec(
        bytes,
        targetWidth: width,
        allowUpscaling: false,
      );
      final frame = await codec.getNextFrame();
      final encoded = await frame.image.toByteData(
        format: ui.ImageByteFormat.png,
      );
      frame.image.dispose();
      codec.dispose();
      if (encoded != null && encoded.lengthInBytes <= 520000) {
        return base64Encode(
          encoded.buffer.asUint8List(
            encoded.offsetInBytes,
            encoded.lengthInBytes,
          ),
        );
      }
    }
    throw StateError('图片过大，菜谱已在本机保存，请压缩图片后重试同步');
  }
}
