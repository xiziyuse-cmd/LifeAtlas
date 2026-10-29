import 'dart:convert';
import 'dart:io';

import 'package:lifeatlas/core/database/app_database.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:lifeatlas/features/skincare/data/skincare_repository.dart';
import 'package:lifeatlas/features/skincare/domain/skincare_models.dart';
import 'package:lifeatlas/features/skincare/domain/skincare_rules.dart';
import 'package:lifeatlas/core/settings/sqlite_app_settings_repository.dart';

import 'support/test_database.dart';

SkinProduct cream({String id = 'cream'}) => SkinProduct(
  id: id,
  name: '面霜',
  category: '面霜',
  evidence: 'verified',
  versionConfirmed: true,
  source: '包装测试资料',
  instructions: '按需保湿',
);
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'basic plan uses verified active products, sunscreen last, skips unknown serums',
    () {
      final products = [
        cream(),
        SkinProduct(
          id: 'sun',
          name: '防晒',
          category: '防晒',
          evidence: 'verified',
          versionConfirmed: true,
          instructions: '按包装',
        ),
        SkinProduct(id: 'serum', name: '未知精华', category: '精华'),
      ];
      final profile = SkinProfile(goals: ['保湿补水']);
      final plan = SkincareRules.basic(products, profile);
      expect(plan.morning.last.productId, 'sun');
      expect(plan.evening.map((s) => s.productId), ['cream']);
      expect(SkincareRules.validate(plan, products, profile), isEmpty);
      expect(
        SkinPlan.fromJson(
          plan.toJson(),
        ).steps(DateTime.now().subtract(const Duration(days: 1)), 'am'),
        isEmpty,
      );
    },
  );
  test(
    'rules block invented ids, retinol mornings, consecutive days, unstable skin and unknowns',
    () {
      final p = SkinProduct(
        id: 'ret',
        name: '视黄醇',
        category: '精华',
        evidence: 'verified',
        versionConfirmed: true,
        active: 'retinol',
        time: '晚间',
        instructions: '夜间使用',
      );
      final step = SkinStep(
        productId: 'ret',
        name: '视黄醇',
        amount: '按包装',
        area: '面部',
        days: [1, 2],
      );
      SkinPlan plan(List<SkinStep> am, List<SkinStep> pm) => SkinPlan(
        id: 'v',
        name: '计划',
        strategy: '说明',
        start: '2026-10-29',
        source: 'ai',
        morning: am,
        evening: pm,
      );
      expect(
        SkincareRules.validate(plan([step], []), [p], SkinProfile()),
        isNotEmpty,
      );
      expect(
        SkincareRules.validate(plan([], [step]), [p], SkinProfile()),
        contains('初始功效护理日之间保留休息日'),
      );
      expect(
        SkincareRules.validate(plan([], [step]), [p], SkinProfile(state: '泛红')),
        contains('当前档案只安排基础护理'),
      );
      expect(
        SkincareRules.validate(plan([], [step]), [], SkinProfile()),
        isNotEmpty,
      );
      expect(
        SkincareRules.validate(plan([], [step]), [
          p.copy({'evidence': 'ai'}),
        ], SkinProfile()),
        isNotEmpty,
      );
    },
  );
  test(
    'catalog import is versioned, wildcard literal and cabinet remains independent',
    () async {
      final db = await openTestAppDatabase();
      addTearDown(db.close);
      final repo = SkincareRepository(database: db);
      final p = cream().copy({'verifiedAt': '2026-10-29'});
      await repo.importCatalog(
        json: jsonEncode({
          'version': 1,
          'products': [
            {
              ...p.toJson(),
              'aliases': ['品牌别名'],
            },
          ],
        }),
      );
      expect((await repo.search('品牌别名')).single.id, 'cream');
      expect(await repo.search('%'), isEmpty);
      await repo.saveProduct(p.copy({'id': 'mine'}));
      await repo.importCatalog(
        json: jsonEncode({
          'version': 2,
          'products': [
            {...p.toJson(), 'name': '新版目录'},
          ],
        }),
      );
      expect((await repo.products()).single.name, '面霜');
      expect((await repo.search('新版')).single.name, '新版目录');
    },
  );
  test(
    'plans activate only after validation and execution has stable, unique snapshots',
    () async {
      final db = await openTestAppDatabase();
      addTearDown(db.close);
      final repo = SkincareRepository(database: db);
      final profile = SkinProfile(goals: ['保湿补水']);
      await repo.saveSetting('profile', profile.toJson());
      await repo.saveProduct(cream());
      final first = SkincareRules.basic(await repo.products(), profile);
      await repo.activate(first);
      final entry = await repo.start(DateTime.now(), 'pm');
      expect(entry.status, '未开始');
      await repo.progress(
        SkinExecution(
          date: entry.date,
          period: entry.period,
          planId: entry.planId,
          steps: entry.steps,
          states: ['done'],
        ),
      );
      expect((await repo.start(DateTime.now(), 'pm')).status, '已完成');
      expect(await repo.history(), hasLength(1));
      await repo.saveProduct(cream().copy({'name': '重命名'}));
      final second = SkincareRules.basic(await repo.products(), profile);
      await repo.activate(second);
      await repo.deleteProduct('cream');
      expect((await repo.execution(entry.date, 'pm'))!.steps.single.name, '面霜');
      expect((await repo.activePlan())!.id, second.id);
      await expectLater(repo.start(DateTime.now(), 'am'), throwsStateError);
      await expectLater(repo.activate(second), throwsStateError);
      expect((await repo.activePlan())!.id, second.id);
    },
  );
  test(
    'v11 migration adds skincare and preserves old tables and settings',
    () async {
      sqfliteFfiInit();
      final directory = await Directory.systemTemp.createTemp('skin-migration');
      addTearDown(() => directory.delete(recursive: true));
      final path = '${directory.path}/life.db';
      final old = AppDatabase(factory: databaseFactoryFfi, databasePath: path);
      final connection = await old.database;
      await connection.insert('app_settings', {
        'setting_key': 'keep',
        'setting_value': 'original',
      });
      for (final table in [
        'skincare_catalog',
        'skincare_settings',
        'skincare_products',
        'skincare_plans',
        'skincare_executions',
      ]) {
        await connection.execute('DROP TABLE $table');
      }
      await connection.insert('recipe', {
        'name': '保留菜谱',
        'image': '',
        'category': '家常菜',
        'difficulty': '简单',
        'cook_time': 10,
        'source_type': 'user',
        'create_time': '2026-10-29',
        'update_time': '2026-10-29',
      });
      await connection.setVersion(11);
      await old.close();
      final upgraded = AppDatabase(
        factory: databaseFactoryFfi,
        databasePath: path,
      );
      addTearDown(upgraded.close);
      final db = await upgraded.database;
      expect(await db.getVersion(), 12);
      expect(
        (await db.query(
          'app_settings',
          where: 'setting_key = ?',
          whereArgs: ['keep'],
        )).single['setting_value'],
        'original',
      );
      expect(await db.query('skincare_products'), isEmpty);
      expect((await db.query('recipe')).single['name'], '保留菜谱');
    },
  );
  test(
    'module enabled state persists independently from existing modules',
    () async {
      final db = await openTestAppDatabase();
      addTearDown(db.close);
      final settings = SqliteAppSettingsRepository(db);
      await settings.saveKitchenModuleEnabled(true);
      await settings.saveSkincareModuleEnabled(true);
      expect((await settings.load()).skincareModuleEnabled, isTrue);
      await settings.saveSkincareModuleEnabled(false);
      expect((await settings.load()).kitchenModuleEnabled, isTrue);
    },
  );
}
