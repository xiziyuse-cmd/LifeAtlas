import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeatlas/core/network/mobile_api.dart';
import 'package:lifeatlas/features/profile/data/body_vault.dart';
import 'package:lifeatlas/features/profile/presentation/body_profile_page.dart';
import 'package:lifeatlas/app/app_controller.dart';
import 'package:lifeatlas/core/settings/sqlite_app_settings_repository.dart';
import 'support/test_database.dart';

class MemoryBodyApi extends MobileApi {
  Object? value;
  bool fail = false;
  @override
  Future<Object?> setting(String key) async => value;
  @override
  Future<void> saveSetting(String key, Object? data) async {
    if (fail) throw StateError('disk');
    value = jsonDecode(jsonEncode(data));
  }
}

void main() {
  testWidgets(
    'unlocked history is removed on background and gender remains editable after unlock',
    (tester) async {
      final db = (await tester.runAsync(openTestAppDatabase))!;
      addTearDown(db.close);
      final controller = AppController(SqliteAppSettingsRepository(db));
      await tester.runAsync(controller.initialize);
      final v = BodyVault(api: MemoryBodyApi());
      await tester.runAsync(() async {
        await v.create('password123');
        await v.save(
          BodyRecord(id: 'a', date: '2026-01-01', values: {'身高': '170'}),
        );
      });
      await tester.pumpWidget(
        MaterialApp(
          home: BodyProfilePage(controller: controller, vault: v),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('历史记录'));
      await tester.pumpAndSettle();
      expect(find.text('修正这条记录'), findsOneWidget);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pumpAndSettle();
      expect(v.unlocked, isFalse);
      expect(find.text('修正这条记录'), findsNothing);
      expect(find.byKey(const ValueKey('body-password')), findsOneWidget);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    },
  );
  test(
    'encrypted persistence, wrong password, recovery, password change, CRUD and lock',
    () async {
      final api = MemoryBodyApi();
      final v = BodyVault(api: api);
      final recovery = await v.create('password123');
      final record = BodyRecord(
        id: '1',
        date: '2026-01-01',
        values: {'胸围': '91.25'},
        note: 'private-note',
      );
      await v.save(record);
      expect(jsonEncode(api.value), isNot(contains('91.25')));
      expect(jsonEncode(api.value), isNot(contains('private-note')));
      v.lock();
      expect(v.records, isEmpty);
      await expectLater(v.save(record), throwsStateError);
      await expectLater(v.unlock('wrong'), throwsStateError);
      await v.unlock('password123');
      expect(v.records.single.values['胸围'], '91.25');
      await v.changePassword('newpassword');
      v.lock();
      await expectLater(v.unlock('password123'), throwsStateError);
      await v.unlock(recovery, recovery: true);
      await v.changePassword('recovered123');
      v.lock();
      await v.unlock('recovered123');
      api.fail = true;
      await expectLater(v.delete('1'), throwsStateError);
      expect(v.records, hasLength(1));
      api.fail = false;
      await v.save(
        BodyRecord(id: '1', date: '2026-01-01', values: {'胸围': '92'}),
      );
      expect(v.records, hasLength(1));
      await v.delete('1');
      expect(v.records, isEmpty);
    },
  );
  test('future, invalid, empty and nonfinite records are refused', () {
    for (final values in [
      <String, String>{},
      {'胸围': 'NaN'},
      {'体重': '-1'},
    ]) {
      expect(
        () =>
            BodyRecord(id: 'a', date: '2026-01-01', values: values).validate(),
        throwsFormatException,
      );
    }
    expect(
      () => BodyRecord(
        id: 'a',
        date: '2999-01-01',
        values: {'胸围': '90'},
      ).validate(),
      throwsFormatException,
    );
  });
  testWidgets(
    'record form marks inherited fields, validates and returns optional fields',
    (tester) async {
      final seed = BodyRecord(
        id: 'old',
        date: '2026-01-01',
        values: {'身高': '170'},
      );
      await tester.pumpWidget(MaterialApp(home: BodyRecordForm(seed: seed)));
      expect(find.text('沿用上次，尚未重新测量'), findsOneWidget);
      await tester.enterText(find.widgetWithText(TextField, '170'), '171');
      await tester.pump();
      expect(find.text('沿用上次，尚未重新测量'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
