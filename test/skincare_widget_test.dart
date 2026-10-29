import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeatlas/features/skincare/application/skincare_reminders.dart';
import 'package:lifeatlas/features/skincare/data/skincare_ai_service.dart';
import 'package:lifeatlas/features/skincare/data/skincare_repository.dart';
import 'package:lifeatlas/features/skincare/domain/skincare_models.dart';
import 'package:lifeatlas/features/skincare/presentation/skincare_page.dart';
import 'package:lifeatlas/features/skincare/presentation/skin_product_page.dart';

import 'package:lifeatlas/features/skincare/domain/skincare_rules.dart';

class NoNotifications extends SkincareReminders {
  NoNotifications(super.repository);
  @override
  bool get supported => false;
}

void main() {
  testWidgets(
    'product search confirms source without ingredient entry fields',
    (tester) async {
      final repo = MemorySkinRepository();
      await repo.importCatalog();
      await tester.pumpWidget(
        MaterialApp(
          home: SkinProductPage(repository: repo, ai: SkincareAiService()),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'C霜');
      await tester.pumpAndSettle();
      await tester.tap(find.text('适乐肤保湿面霜 Moisturizing Cream'));
      await tester.pumpAndSettle();
      expect(find.textContaining('美国官网'), findsWidgets);
      expect(find.byType(TextField), findsNWidgets(2)); // search and name only
      await tester.scrollUntilVisible(
        find.text('已核对地区、产品版本和包装说明一致'),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('已核对地区、产品版本和包装说明一致'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'rule plan preview activates then execution persists a completed session',
    (tester) async {
      final repo = MemorySkinRepository();
      await repo.saveSetting('profile', SkinProfile(goals: ['保湿补水']).toJson());
      await repo.saveProduct(
        SkinProduct(
          id: 'cream',
          name: '测试面霜',
          category: '面霜',
          evidence: 'verified',
          versionConfirmed: true,
          instructions: '按需保湿',
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SkincarePage(
              repository: repo,
              ai: SkincareAiService(),
              reminders: NoNotifications(repo),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('使用基础规则生成'),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('使用基础规则生成'));
      await tester.pumpAndSettle();
      expect(find.text('计划预览'), findsOneWidget);
      expect(await repo.activePlan(), isNull);
      await tester.scrollUntilVisible(
        find.text('确认并启用此版本'),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('确认并启用此版本'));
      await tester.pumpAndSettle();
      expect(await repo.activePlan(), isNotNull);
      await tester.scrollUntilVisible(
        find.text('开始护理').first,
        -250,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('开始护理').first);
      await tester.pumpAndSettle();
      expect(find.text('完成这一步'), findsOneWidget);
      await tester.tap(find.text('完成这一步'));
      await tester.pumpAndSettle();
      expect((await repo.history()).single.status, '已完成');
      expect(
        (await repo.history()).single.steps.single.productSnapshot['name'],
        '测试面霜',
      );
      expect(tester.takeException(), isNull);
    },
  );
}

// Widget tests exercise the UI contract without real SQLite isolate work inside
// Flutter's fake clock. Real persistence and migrations are in skincare_test.
class MemorySkinRepository extends SkincareRepository {
  final _settings = <String, Object>{};
  final _products = <String, SkinProduct>{};
  final _entries = <String, SkinExecution>{};
  SkinPlan? _plan;
  @override
  Future<void> importCatalog({String? json}) async {}
  @override
  Future<List<SkinProduct>> search(
    String query, {
    bool barcode = false,
  }) async => [
    SkinProduct(
      id: 'catalog',
      name: '适乐肤保湿面霜 Moisturizing Cream',
      category: '面霜',
      brand: 'CeraVe',
      region: '美国官网',
      source: 'https://www.cerave.com',
      verifiedAt: '2026-10-29',
      evidence: 'verified',
      instructions: '按需保湿',
    ),
  ];
  @override
  Future<Object?> setting(String key) async => _settings[key];
  @override
  Future<void> saveSetting(String key, Object value) async {
    _settings[key] = value;
  }

  @override
  Future<SkinProfile?> profile() async => _settings['profile'] == null
      ? null
      : SkinProfile.fromJson(
          Map<String, dynamic>.from(_settings['profile'] as Map),
        );
  @override
  Future<List<SkinProduct>> products() async => _products.values.toList();
  @override
  Future<void> saveProduct(SkinProduct product) async {
    _products[product.id] = product;
  }

  @override
  Future<SkinPlan?> activePlan() async => _plan;
  @override
  Future<void> activate(SkinPlan plan) async {
    final errors = SkincareRules.validate(
      plan,
      await products(),
      (await profile())!,
    );
    if (errors.isNotEmpty) throw StateError(errors.join('\n'));
    SkinStep snapshot(SkinStep s) => SkinStep(
      productId: s.productId,
      name: s.name,
      amount: s.amount,
      area: s.area,
      note: s.note,
      days: s.days,
      productSnapshot: _products[s.productId]!.toJson(),
    );
    _plan = SkinPlan(
      id: plan.id,
      name: plan.name,
      strategy: plan.strategy,
      start: plan.start,
      source: plan.source,
      morning: plan.morning.map(snapshot).toList(),
      evening: plan.evening.map(snapshot).toList(),
    );
  }

  @override
  Future<SkinExecution> start(DateTime date, String period) async {
    final steps = _plan!.steps(date, period);
    return _entries.putIfAbsent(
      '${skinDate(date)}-$period',
      () => SkinExecution(
        date: skinDate(date),
        period: period,
        planId: _plan!.id,
        steps: steps,
        states: List.filled(steps.length, 'pending'),
      ),
    );
  }

  @override
  Future<void> progress(SkinExecution entry) async {
    _entries['${entry.date}-${entry.period}'] = entry;
  }

  @override
  Future<List<SkinExecution>> history() async => _entries.values.toList();
}
