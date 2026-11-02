import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:package_info_plus/package_info_plus.dart';
import 'package:sqflite/sqflite.dart';

import '../../../core/database/app_database.dart';
import '../../../core/config/feedback_config.dart';

class DeveloperFeedback {
  const DeveloperFeedback({
    required this.content,
    required this.version,
    this.subject = '',
    this.contact = '',
  });
  final String content, version, subject, contact;
  Map<String, Object?> toJson() => {
    'content': content.trim(),
    'version': version,
    'subject': subject.trim(),
    'contact': contact.trim(),
  };
  factory DeveloperFeedback.fromJson(Map<String, dynamic> json) =>
      DeveloperFeedback(
        content: json['content'] as String,
        version: json['version'] as String,
        subject: json['subject'] as String,
        contact: json['contact'] as String,
      );
}

class FeedbackHttpResult {
  const FeedbackHttpResult(this.status, this.body);
  final int status;
  final Map<String, dynamic> body;
}

class FeedbackSubmissionException implements Exception {
  const FeedbackSubmissionException(this.message);
  final String message;
  @override
  String toString() => message;
}

typedef FeedbackPost =
    Future<FeedbackHttpResult> Function(Uri uri, Map<String, Object?> body);

class DeveloperContactService {
  DeveloperContactService({AppDatabase? database, FeedbackPost? post})
    : _database = database ?? AppDatabase(),
      _post = post ?? _httpPost;
  final AppDatabase _database;
  final FeedbackPost _post;
  static const _pendingKey = 'feedback_pending_submission';
  static const _installationKey = 'feedback_installation_id';

  Future<String> loadVersion() async {
    final info = await PackageInfo.fromPlatform();
    if (info.version.trim().isEmpty) throw StateError('版本未读取');
    return info.buildNumber.isEmpty
        ? info.version
        : '${info.version}+${info.buildNumber}';
  }

  Future<DeveloperFeedback?> loadPending() async {
    final db = await _database.database;
    final rows = await db.query(
      'app_settings',
      where: 'setting_key = ?',
      whereArgs: [_pendingKey],
    );
    if (rows.isEmpty) return null;
    return DeveloperFeedback.fromJson(
      jsonDecode(rows.first['setting_value'] as String) as Map<String, dynamic>,
    );
  }

  static String _uuid() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 15) | 64;
    bytes[8] = (bytes[8] & 63) | 128;
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
  }

  Future<void> submit(DeveloperFeedback feedback) async {
    if (feedback.content.trim().isEmpty ||
        feedback.content.length > 4000 ||
        feedback.subject.length > 80 ||
        feedback.contact.length > 100 ||
        feedback.version.trim().isEmpty) {
      throw const FeedbackSubmissionException('请检查反馈内容和版本');
    }
    final db = await _database.database;
    final body = await db.transaction((txn) async {
      final pending = await txn.query(
        'app_settings',
        where: 'setting_key = ?',
        whereArgs: [_pendingKey],
      );
      final current = feedback.toJson();
      if (pending.isNotEmpty) {
        final old =
            jsonDecode(pending.first['setting_value'] as String)
                as Map<String, dynamic>;
        if ([
          'content',
          'subject',
          'contact',
        ].every((key) => old[key] == current[key])) {
          return old;
        }
      }
      final installations = await txn.query(
        'app_settings',
        where: 'setting_key = ?',
        whereArgs: [_installationKey],
      );
      final installation = installations.isEmpty
          ? _uuid()
          : installations.first['setting_value'] as String;
      if (installations.isEmpty) {
        await txn.insert('app_settings', {
          'setting_key': _installationKey,
          'setting_value': installation,
        });
      }
      final value = <String, Object?>{
        ...current,
        'id': _uuid(),
        'installationId': installation,
        'platform': Platform.operatingSystem,
      };
      await txn.insert('app_settings', {
        'setting_key': _pendingKey,
        'setting_value': jsonEncode(value),
      }, conflictAlgorithm: ConflictAlgorithm.replace);
      return value;
    });
    try {
      final response = await _post(
        Uri.parse(FeedbackConfig.endpoint),
        body,
      ).timeout(const Duration(seconds: 30));
      if (response.status == 429) {
        throw const FeedbackSubmissionException('今天提交较频繁，请明天再试；内容已保留');
      }
      if (response.status == 400 || response.status == 413) {
        throw const FeedbackSubmissionException('请检查反馈长度和填写内容，内容已保留');
      }
      if (![200, 201].contains(response.status) ||
          response.body['id'] != body['id'] ||
          response.body['status'] != 'received' ||
          DateTime.tryParse(response.body['receivedAt']?.toString() ?? '') ==
              null) {
        throw const FeedbackSubmissionException('提交未确认，填写内容已保留，请重试');
      }
      await db.transaction((txn) async {
        final pending = await txn.query(
          'app_settings',
          where: 'setting_key = ?',
          whereArgs: [_pendingKey],
        );
        if (pending.isNotEmpty &&
            (jsonDecode(pending.first['setting_value'] as String)
                    as Map)['id'] ==
                body['id']) {
          await txn.delete(
            'app_settings',
            where: 'setting_key = ?',
            whereArgs: [_pendingKey],
          );
        }
      });
    } on FeedbackSubmissionException {
      rethrow;
    } catch (_) {
      throw const FeedbackSubmissionException('提交未确认，填写内容已保留，请检查网络后重试');
    }
  }

  static Future<FeedbackHttpResult> _httpPost(
    Uri uri,
    Map<String, Object?> body,
  ) async {
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 10);
    try {
      final request = await client.postUrl(uri);
      request.followRedirects = false;
      request.headers.contentType = ContentType.json;
      request.write(jsonEncode(body));
      final response = await request.close().timeout(
        const Duration(seconds: 25),
      );
      final bytes = <int>[];
      await for (final chunk in response.timeout(const Duration(seconds: 10))) {
        bytes.addAll(chunk);
        if (bytes.length > 8192) {
          throw const FormatException('Response too large');
        }
      }
      return FeedbackHttpResult(
        response.statusCode,
        jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>,
      );
    } finally {
      client.close(force: true);
    }
  }
}
