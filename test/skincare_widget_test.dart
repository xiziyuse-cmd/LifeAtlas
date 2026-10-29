import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeatlas/features/skincare/application/skincare_reminders.dart';
import 'package:lifeatlas/features/skincare/data/skincare_ai_service.dart';
import 'package:lifeatlas/features/skincare/data/skincare_repository.dart';
import 'package:lifeatlas/features/skincare/domain/skincare_models.dart';
import 'package:lifeatlas/features/skincare/presentation/skincare_page.dart';
import 'package:lifeatlas/features/skincare/presentation/skin_product_page.dart';

import 'support/test_database.dart';

class NoNotifications extends SkincareReminders {
  NoNotifications(super.repository);
  @override
  bool get supported => false;
}

void main() {
  testWidgets(
    'product search confirms source without ingredient entry fields',
    (tester) async {
      final database = await openTestAppDatabase();
      addTearDown(database.close);
      final repo = SkincareRepository(database: database);
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
      expect(find.text('已核对地区、产品版本和包装说明一致'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'rule plan preview activates then execution persists a completed session',
    (tester) async {
      final database = await openTestAppDatabase();
      addTearDown(database.close);
      final repo = SkincareRepository(database: database);
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
      await tester.ensureVisible(find.text('使用基础规则生成'));
      await tester.tap(find.text('使用基础规则生成'));
      await tester.pumpAndSettle();
      expect(find.text('计划预览'), findsOneWidget);
      expect(await repo.activePlan(), isNull);
      await tester.ensureVisible(find.text('确认并启用此版本'));
      await tester.tap(find.text('确认并启用此版本'));
      await tester.pumpAndSettle();
      expect(await repo.activePlan(), isNotNull);
      await tester.ensureVisible(find.text('开始护理').first);
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
