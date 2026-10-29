import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:sqflite/sqflite.dart';

import '../../../core/database/app_database.dart';
import '../domain/skincare_models.dart';
import '../domain/skincare_rules.dart';

class SkincareRepository {
  SkincareRepository({AppDatabase? database})
    : _database = database ?? AppDatabase();
  final AppDatabase _database;
  Future<void> importCatalog({String? json}) async {
    final data = object(
      jsonDecode(
        json ??
            await rootBundle.loadString('assets/data/skincare_catalog.json'),
      ),
    );
    final version = data['version'] as int;
    if ((await setting('catalogVersion') as int? ?? 0) >= version) return;
    final entries = (data['products'] as List).map((e) => object(e)).toList();
    final db = await _database.database;
    await db.transaction((tx) async {
      for (final m in entries) {
        final p = SkinProduct.fromJson(m);
        if (p.id.isEmpty ||
            p.name.isEmpty ||
            p.source.isEmpty ||
            p.verifiedAt.isEmpty) {
          throw const FormatException('产品资料缺少来源');
        }
        await tx.insert('skincare_catalog', {
          'id': p.id,
          'data': jsonEncode(m),
          'search_text':
              '${p.name} ${p.brand} ${(m['aliases'] as List? ?? []).join(' ')}'
                  .toLowerCase(),
          'barcode': p.barcode,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
      await tx.insert('skincare_settings', {
        'key': 'catalogVersion',
        'data': jsonEncode(version),
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    });
  }

  Future<List<SkinProduct>> search(String query, {bool barcode = false}) async {
    final db = await _database.database;
    final q = query.trim().toLowerCase();
    final tokens = q.isEmpty ? [''] : q.split(RegExp(r'\s+')).take(6).toList();
    final rows = await db.query(
      'skincare_catalog',
      where: barcode
          ? 'barcode = ? AND barcode != ?'
          : List.filled(
              tokens.length,
              "search_text LIKE ? ESCAPE '\\'",
            ).join(' AND '),
      whereArgs: barcode
          ? [q, '']
          : tokens
                .map(
                  (token) =>
                      '%${token.replaceAll('\\', '\\\\').replaceAll('%', '\\%').replaceAll('_', '\\_')}%',
                )
                .toList(),
      limit: 40,
    );
    return rows
        .map(
          (r) => SkinProduct.fromJson(object(jsonDecode(r['data'] as String))),
        )
        .toList();
  }

  Future<Object?> setting(String key) async {
    final rows = await (await _database.database).query(
      'skincare_settings',
      where: 'key = ?',
      whereArgs: [key],
    );
    return rows.isEmpty ? null : jsonDecode(rows.first['data'] as String);
  }

  Future<void> saveSetting(String key, Object value) async =>
      (await _database.database).insert('skincare_settings', {
        'key': key,
        'data': jsonEncode(value),
      }, conflictAlgorithm: ConflictAlgorithm.replace);
  Future<SkinProfile?> profile() async {
    final m = await setting('profile');
    return m == null ? null : SkinProfile.fromJson(object(m));
  }

  Future<List<SkinProduct>> products() async =>
      (await (await _database.database).query('skincare_products'))
          .map(
            (r) =>
                SkinProduct.fromJson(object(jsonDecode(r['data'] as String))),
          )
          .toList();
  Future<void> saveProduct(SkinProduct product) async =>
      (await _database.database).insert('skincare_products', {
        'id': product.id,
        'data': jsonEncode(product.toJson()),
      }, conflictAlgorithm: ConflictAlgorithm.replace);
  Future<void> deleteProduct(String id) async => (await _database.database)
      .delete('skincare_products', where: 'id = ?', whereArgs: [id]);
  Future<SkinPlan?> activePlan() async {
    final rows = await (await _database.database).query(
      'skincare_plans',
      where: 'active = 1',
      limit: 1,
    );
    return rows.isEmpty
        ? null
        : SkinPlan.fromJson(object(jsonDecode(rows.first['data'] as String)));
  }

  Future<void> activate(SkinPlan plan) async {
    final profileData = await profile();
    if (profileData == null) throw StateError('请先建立皮肤档案');
    final errors = SkincareRules.validate(plan, await products(), profileData);
    if (errors.isNotEmpty) throw StateError(errors.join('\n'));
    final cabinet = {for (final p in await products()) p.id: p};
    SkinStep snapshot(SkinStep s) => SkinStep(
      productId: s.productId,
      name: cabinet[s.productId]!.name,
      amount: s.amount,
      area: s.area,
      note: s.note,
      days: [...s.days],
      productSnapshot: cabinet[s.productId]!.toJson(),
    );
    final saved = SkinPlan(
      id: plan.id,
      name: plan.name,
      strategy: plan.strategy,
      start: plan.start,
      source: plan.source,
      morning: plan.morning.map(snapshot).toList(),
      evening: plan.evening.map(snapshot).toList(),
    );
    await (await _database.database).transaction((tx) async {
      await tx.update('skincare_plans', {'active': 0});
      await tx.insert('skincare_plans', {
        'id': plan.id,
        'data': jsonEncode(saved.toJson()),
        'active': 1,
      });
    });
  }

  Future<SkinExecution?> execution(String date, String period) async {
    final rows = await (await _database.database).query(
      'skincare_executions',
      where: 'date = ? AND period = ?',
      whereArgs: [date, period],
    );
    return rows.isEmpty
        ? null
        : SkinExecution.fromJson(
            object(jsonDecode(rows.first['data'] as String)),
          );
  }

  Future<List<SkinExecution>> history() async =>
      (await (await _database.database).query(
            'skincare_executions',
            orderBy: 'date DESC, period',
            limit: 200,
          ))
          .map(
            (r) =>
                SkinExecution.fromJson(object(jsonDecode(r['data'] as String))),
          )
          .toList();
  Future<SkinExecution> start(DateTime date, String period) async {
    final existing = await execution(skinDate(date), period);
    if (existing != null) {
      if (!existing.finished) {
        final cabinet = {for (final p in await products()) p.id: p};
        for (var i = 0; i < existing.steps.length; i++) {
          if (existing.states[i] == 'pending' &&
              cabinet[existing.steps[i].productId]?.usable != true) {
            throw StateError('未完成步骤中的产品已停用、删除或到期，请调整后续计划');
          }
        }
      }
      return existing;
    }
    final plan = await activePlan();
    if (plan == null) throw StateError('请先确认护肤计划');
    final steps = plan.steps(date, period);
    if (steps.isEmpty) throw StateError('今天没有对应护理步骤');
    final profileData = await profile();
    if (profileData == null) throw StateError('请先建立皮肤档案');
    final errors = SkincareRules.validate(plan, await products(), profileData);
    if (errors.isNotEmpty) {
      throw StateError('产品或档案已变更，请重新确认计划：\n${errors.join('\n')}');
    }
    final entry = SkinExecution(
      date: skinDate(date),
      period: period,
      planId: plan.id,
      steps: steps,
      states: List.filled(steps.length, 'pending'),
      updated: DateTime.now().toIso8601String(),
    );
    await (await _database.database).insert('skincare_executions', {
      'date': entry.date,
      'period': entry.period,
      'data': jsonEncode(entry.toJson()),
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
    return (await execution(entry.date, period))!;
  }

  Future<void> progress(SkinExecution entry) async {
    if (entry.states.length != entry.steps.length ||
        entry.states.any((s) => !['pending', 'done', 'skipped'].contains(s))) {
      throw const FormatException('执行状态不完整');
    }
    await (await _database.database).update(
      'skincare_executions',
      {'data': jsonEncode(entry.toJson())},
      where: 'date = ? AND period = ?',
      whereArgs: [entry.date, entry.period],
    );
  }

  /// Stable read interface for future native widgets.
  Future<Map<String, dynamic>> todaySummary() async {
    final plan = await activePlan();
    final now = DateTime.now();
    return {
      'date': skinDate(now),
      for (final period in ['am', 'pm'])
        period: {
          'steps':
              plan?.steps(now, period).map((s) => s.toJson()).toList() ?? [],
          'status': (await execution(skinDate(now), period))?.status ?? '未开始',
        },
    };
  }
}
