import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:lifeatlas/core/database/app_database.dart';
import 'package:lifeatlas/features/profile/data/developer_contact_service.dart';
import 'package:lifeatlas/features/profile/presentation/contact_developer_page.dart';

class _Contact extends DeveloperContactService {
  bool failVersion = false, failSend = false;
  DeveloperFeedback? sent, pending;
  @override
  Future<String> loadVersion() async {
    if (failVersion) throw StateError('no version');
    return '1.4.9+25';
  }

  @override
  Future<DeveloperFeedback?> loadPending() async => pending;
  @override
  Future<void> submit(DeveloperFeedback feedback) async {
    sent = feedback;
    if (failSend) throw const FeedbackSubmissionException('提交未确认，内容已保留，请重试');
  }
}

Future<void> scrollTo(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(
    finder,
    200,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  test(
    'durable pending ID and original version survive timeout and service recreation; receipt clears pending',
    () async {
      final db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
      await db.execute(
        'CREATE TABLE app_settings (setting_key TEXT PRIMARY KEY, setting_value TEXT NOT NULL)',
      );
      final database = AppDatabase.forTesting(db);
      Map<String, Object?>? first;
      final failed = DeveloperContactService(
        database: database,
        post: (uri, body) async {
          expect(uri.scheme, 'https');
          first = Map.of(body);
          throw TimeoutException('ambiguous');
        },
      );
      const feedback = DeveloperFeedback(
        content: '中文 & +\n新行',
        subject: '建议',
        contact: 'a+b@example.com',
        version: '1.4.9+25',
      );
      await expectLater(
        failed.submit(feedback),
        throwsA(isA<FeedbackSubmissionException>()),
      );
      expect((await failed.loadPending())!.content, feedback.content);
      final retry = DeveloperContactService(
        database: database,
        post: (uri, body) async {
          expect(body, first);
          return FeedbackHttpResult(200, {
            'id': body['id'],
            'status': 'received',
            'receivedAt': DateTime.now().toUtc().toIso8601String(),
          });
        },
      );
      await retry.submit(
        DeveloperFeedback(
          content: feedback.content,
          subject: feedback.subject,
          contact: feedback.contact,
          version: 'future-version',
        ),
      );
      expect(await retry.loadPending(), isNull);
      expect(first!['version'], '1.4.9+25');
      expect(first!['id'], matches(RegExp(r'^[0-9a-f-]{14}4[0-9a-f-]{21}$')));
      await db.close();
    },
  );

  test(
    'invalid receipts and rate limits retain content; edits get a new ID with stable installation',
    () async {
      final db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
      await db.execute(
        'CREATE TABLE app_settings (setting_key TEXT PRIMARY KEY, setting_value TEXT NOT NULL)',
      );
      final calls = <Map<String, Object?>>[];
      final service = DeveloperContactService(
        database: AppDatabase.forTesting(db),
        post: (uri, body) async {
          calls.add(Map.of(body));
          return calls.length == 1
              ? const FeedbackHttpResult(201, {'id': 'wrong'})
              : const FeedbackHttpResult(429, {});
        },
      );
      await expectLater(
        service.submit(
          const DeveloperFeedback(content: 'one', version: '1.4.9+25'),
        ),
        throwsA(isA<FeedbackSubmissionException>()),
      );
      await expectLater(
        service.submit(
          const DeveloperFeedback(content: 'two', version: '1.4.9+25'),
        ),
        throwsA(isA<FeedbackSubmissionException>()),
      );
      expect(calls[0]['id'], isNot(calls[1]['id']));
      expect(calls[0]['installationId'], calls[1]['installationId']);
      expect((await service.loadPending())!.content, 'two');
      await db.close();
    },
  );

  testWidgets(
    'requires content, submits version directly and only clears after confirmed success',
    (tester) async {
      final service = _Contact();
      await tester.pumpWidget(
        MaterialApp(home: ContactDeveloperPage(service: service)),
      );
      await tester.pumpAndSettle();
      expect(find.text('当前版本：1.4.9+25'), findsOneWidget);
      expect(find.text('发送邮件'), findsNothing);
      await scrollTo(tester, find.text('提交反馈'));
      await tester.tap(find.text('提交反馈'));
      await tester.pumpAndSettle();
      expect(service.sent, isNull);
      expect(find.text('请填写反馈内容'), findsOneWidget);
      await tester.enterText(find.widgetWithText(TextField, '反馈内容'), '请支持更多分类');
      await scrollTo(tester, find.text('提交反馈'));
      await tester.tap(find.text('提交反馈'));
      await tester.pumpAndSettle();
      expect(service.sent!.content, '请支持更多分类');
      expect(service.sent!.version, '1.4.9+25');
      expect(find.byKey(const ValueKey('feedback-success')), findsOneWidget);
      expect(
        tester
            .widget<TextField>(find.widgetWithText(TextField, '反馈内容'))
            .controller!
            .text,
        '',
      );
    },
  );

  testWidgets('restores draft, failed send keeps inputs and retry succeeds', (
    tester,
  ) async {
    final service = _Contact()
      ..failSend = true
      ..pending = const DeveloperFeedback(
        content: '已保存的反馈',
        version: '1.4.9+25',
        contact: 'qq123',
      );
    await tester.pumpWidget(
      MaterialApp(home: ContactDeveloperPage(service: service)),
    );
    await tester.pumpAndSettle();
    expect(find.text('已保存的反馈'), findsOneWidget);
    await scrollTo(tester, find.text('提交反馈'));
    await tester.tap(find.text('提交反馈'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('feedback-success')), findsNothing);
    expect(
      tester
          .widget<TextField>(find.widgetWithText(TextField, '反馈内容'))
          .controller!
          .text,
      '已保存的反馈',
    );
    service.failSend = false;
    await tester.tap(find.text('提交反馈'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('feedback-success')), findsOneWidget);
  });

  testWidgets('version failure disables sending and supports retry', (
    tester,
  ) async {
    final service = _Contact()..failVersion = true;
    await tester.pumpWidget(
      MaterialApp(home: ContactDeveloperPage(service: service)),
    );
    await tester.pumpAndSettle();
    await scrollTo(tester, find.text('提交反馈'));
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );
    service.failVersion = false;
    await tester.tap(find.text('读取失败，点击重试'));
    await tester.pumpAndSettle();
    expect(find.text('当前版本：1.4.9+25'), findsOneWidget);
  });

  testWidgets('narrow phone with keyboard and large text stays scrollable', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 760);
    tester.view.devicePixelRatio = 1;
    tester.view.viewInsets = const FakeViewPadding(bottom: 280);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(1.6)),
          child: child!,
        ),
        home: ContactDeveloperPage(service: _Contact()),
      ),
    );
    await tester.pumpAndSettle();
    await scrollTo(tester, find.text('提交反馈'));
    expect(tester.takeException(), isNull);
  });
}
