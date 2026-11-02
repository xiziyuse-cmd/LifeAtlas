import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import '../database/app_database.dart';

class MobileApi {
  MobileApi({AppDatabase? database, HttpClient? client})
    : database = database ?? AppDatabase(),
      _client = client ?? HttpClient() {
    _client.userAgent = 'LifeAtlas/2.3';
  }
  static MobileApi shared = MobileApi();
  final AppDatabase database;
  final HttpClient _client;
  Future<Map<String, dynamic>>? _identity;
  Future<void>? _registration;
  static final endpoint = Uri.parse(
    'https://lifeatlas-updates.xiziyuse.workers.dev/v1/app',
  );
  Future<Object?> setting(String key) async {
    final db = await database.database;
    final rows = await db.query(
      'app_settings',
      where: 'setting_key = ?',
      whereArgs: [key],
    );
    return rows.isEmpty
        ? null
        : jsonDecode(rows.first['setting_value'] as String);
  }

  Future<void> saveSetting(String key, Object? value) async {
    final db = await database.database;
    await db.rawInsert(
      'INSERT OR REPLACE INTO app_settings(setting_key,setting_value) VALUES(?,?)',
      [key, jsonEncode(value)],
    );
  }

  Future<Map<String, dynamic>> identity() => _identity ??= _createIdentity();
  Future<Map<String, dynamic>> _createIdentity() async {
    final db = await database.database;
    return db.transaction((tx) async {
      final rows = await tx.query(
        'app_settings',
        where: 'setting_key = ?',
        whereArgs: ['mobile_identity_v1'],
      );
      if (rows.isNotEmpty) {
        return Map<String, dynamic>.from(
          jsonDecode(rows.first['setting_value'] as String) as Map,
        );
      }
      final rng = Random.secure();
      final bytes = List<int>.generate(16, (_) => rng.nextInt(256));
      bytes[6] = (bytes[6] & 15) | 64;
      bytes[8] = (bytes[8] & 63) | 128;
      final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
      final id =
          '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
      final value = <String, dynamic>{
        'ownerId': id,
        'token': base64UrlEncode(
          List.generate(32, (_) => rng.nextInt(256)),
        ).replaceAll('=', ''),
        'phoneBinding': null,
      };
      await tx.insert('app_settings', {
        'setting_key': 'mobile_identity_v1',
        'setting_value': jsonEncode(value),
      });
      return value;
    });
  }

  Future<Map<String, dynamic>> call(
    String action, [
    Map<String, Object?> data = const {},
  ]) async {
    final identity = await this.identity();
    try {
      await (_registration ??= _request({
        ...identity,
        'action': 'register',
      }).then((_) {}));
    } catch (_) {
      _registration = null;
      rethrow;
    }
    return _request({...data, ...identity, 'action': action});
  }

  Future<Map<String, dynamic>> _request(Map<String, Object?> data) async {
    return (() async {
      final req = await _client.postUrl(endpoint);
      req.followRedirects = false;
      req.headers.contentType = ContentType.json;
      req.write(jsonEncode(data));
      final response = await req.close();
      final bytes = <int>[];
      await for (final chunk in response) {
        bytes.addAll(chunk);
        if (bytes.length > 5000000) {
          throw const FormatException('服务响应过大');
        }
      }
      final result = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
      if (response.statusCode != 200) {
        throw StateError(result['error'] as String? ?? '服务暂不可用');
      }
      return result;
    })().timeout(const Duration(seconds: 25));
  }
}
