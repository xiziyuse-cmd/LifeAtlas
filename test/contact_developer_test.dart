import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeatlas/features/profile/data/developer_contact_service.dart';
import 'package:lifeatlas/features/profile/presentation/contact_developer_page.dart';

class _Contact extends DeveloperContactService {
  bool failVersion = false;
  bool open = true;
  bool throwMail = false;
  DeveloperFeedback? sent;
  @override
  Future<String> loadVersion() async {
    if (failVersion) throw StateError('no version');
    return '1.4.8+24';
  }

  @override
  Future<bool> openMail(DeveloperFeedback feedback) async {
    sent = feedback;
    if (throwMail) throw StateError('no email');
    return open;
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
  test(
    'mail URI keeps recipient, version, Unicode and special characters intact',
    () {
      const feedback = DeveloperFeedback(
        content: '中文 & ? + #\n换行',
        subject: '意见 A & B\n新行',
        contact: 'a+b@example.com',
        version: '1.4.8+24',
      );
      final uri = feedback.uri;
      expect(uri.scheme, 'mailto');
      expect(uri.path, '1786857315@qq.com');
      expect(
        uri.queryParameters['subject'],
        'LifeAtlas 反馈 [1.4.8+24] 意见 A & B 新行',
      );
      expect(uri.queryParameters['body'], feedback.body);
      expect(uri.toString(), contains('%20'));
      expect(feedback.copyText, contains('软件版本：1.4.8+24'));
    },
  );

  testWidgets(
    'feedback validates empty input and opens versioned email without claiming delivery',
    (tester) async {
      final service = _Contact();
      await tester.pumpWidget(
        MaterialApp(home: ContactDeveloperPage(service: service)),
      );
      await tester.pumpAndSettle();
      expect(find.text('当前版本：1.4.8+24'), findsOneWidget);
      await scrollTo(tester, find.text('发送邮件'));
      await tester.tap(find.text('发送邮件'));
      await tester.pumpAndSettle();
      expect(service.sent, isNull);
      expect(find.text('请填写反馈内容'), findsOneWidget);
      await tester.enterText(find.widgetWithText(TextField, '反馈内容'), '请支持更多分类');
      await scrollTo(tester, find.text('发送邮件'));
      await tester.tap(find.text('发送邮件'));
      await tester.pumpAndSettle();
      expect(service.sent!.body, contains('请支持更多分类'));
      expect(service.sent!.body, contains('1.4.8+24'));
      expect(find.text('已打开邮箱，请在邮箱中确认发送'), findsOneWidget);
      expect(
        tester
            .widget<TextField>(find.widgetWithText(TextField, '反馈内容'))
            .controller!
            .text,
        '请支持更多分类',
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('no email app preserves input and copies complete fallback', (
    tester,
  ) async {
    final service = _Contact()..open = false;
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map)['text'] as String;
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    await tester.pumpWidget(
      MaterialApp(home: ContactDeveloperPage(service: service)),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, '反馈内容'), '保存问题');
    await scrollTo(tester, find.text('发送邮件'));
    await tester.tap(find.text('发送邮件'));
    await tester.pumpAndSettle();
    expect(find.textContaining('未能打开邮箱'), findsOneWidget);
    await scrollTo(tester, find.text('复制反馈内容'));
    await tester.tap(find.text('复制反馈内容'));
    await tester.pumpAndSettle();
    expect(copied, contains('1786857315@qq.com'));
    expect(copied, contains('保存问题'));
    expect(copied, contains('1.4.8+24'));
    service.throwMail = true;
    await scrollTo(tester, find.text('发送邮件'));
    await tester.tap(find.text('发送邮件'));
    await tester.pumpAndSettle();
    expect(find.textContaining('打开邮箱失败'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'version failure blocks sending and retry restores real version',
    (tester) async {
      final service = _Contact()..failVersion = true;
      await tester.pumpWidget(
        MaterialApp(home: ContactDeveloperPage(service: service)),
      );
      await tester.pumpAndSettle();
      expect(find.text('版本读取失败，点击重试'), findsOneWidget);
      await scrollTo(tester, find.text('发送邮件'));
      expect(
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, '发送邮件'))
            .onPressed,
        isNull,
      );
      service.failVersion = false;
      await tester.tap(find.text('版本读取失败，点击重试'));
      await tester.pumpAndSettle();
      expect(find.text('当前版本：1.4.8+24'), findsOneWidget);
    },
  );

  testWidgets(
    'contact page fits narrow large text with keyboard and version footer',
    (tester) async {
      tester.view.physicalSize = const Size(320, 720);
      tester.view.devicePixelRatio = 1;
      tester.view.viewInsets = FakeViewPadding(bottom: 260);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetViewInsets);
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(1.5)),
            child: child!,
          ),
          home: ContactDeveloperPage(service: _Contact()),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        tester.getBottomRight(find.text('当前版本：1.4.8+24')).dy,
        lessThan(460),
      );
      await scrollTo(tester, find.text('发送邮件'));
      expect(tester.takeException(), isNull);
    },
  );
}
