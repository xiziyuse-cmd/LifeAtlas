import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeatlas/app/app_controller.dart';
import 'package:lifeatlas/core/settings/app_settings.dart';
import 'package:lifeatlas/core/settings/app_settings_repository.dart';
import 'package:lifeatlas/features/navigation/presentation/app_shell.dart';
import 'package:lifeatlas/features/updates/app_update_notice.dart';
import 'package:lifeatlas/features/updates/app_update_service.dart';

AppRelease release(
  String version, {
  int build = 39,
  int minSdk = 24,
}) => AppRelease(
  version: version,
  build: build,
  minSdk: minSdk,
  notes: '版本说明',
  size: 1024,
  sha256: 'a' * 64,
  url: Uri.parse(
    'https://lifeatlas-updates.xiziyuse.workers.dev/v1/update/latest?download=1',
  ),
);

class NoticeService extends AppUpdateService {
  AppRelease? result;
  bool fail = false, closed = false;
  int calls = 0, build = 38, sdk = 35;
  Completer<AppRelease?>? pending;
  @override
  Future<AppRelease?> check() async {
    calls++;
    if (fail) throw StateError('offline');
    return pending == null ? result : await pending!.future;
  }

  @override
  Future<Map<String, dynamic>> deviceInfo() async => {
    'version': '2.5.0',
    'build': build,
    'sdk': sdk,
  };
  @override
  void close() {
    closed = true;
    super.close();
  }
}

class NoticeSettings extends Fake implements AppSettingsRepository {
  @override
  Future<AppSettings> load() async => const AppSettings();
}

void main() {
  test(
    'only X.0.0 is a home major release; all requested minor examples use the dot',
    () {
      for (final v in ['3.0.0', '4.0.0', '10.0.0']) {
        expect(release(v).isMajorRelease, true);
      }
      for (final v in ['3.1.0', '3.2.0', '3.1.1', '3.1.2', '2.5.1']) {
        expect(release(v).isMajorRelease, false);
      }
    },
  );

  test(
    'minor dot is based on newer installable build and clears only on a successful observation',
    () async {
      final service = NoticeService()..result = release('3.1.0');
      final notice = AppUpdateNotice(service: service, supported: true);
      addTearDown(notice.dispose);
      await notice.check();
      expect(notice.hasMinorUpdate, true);
      service.fail = true;
      await notice.check();
      expect(notice.hasMinorUpdate, true);
      service.fail = false;
      service.build = 39;
      await notice.check();
      expect(notice.hasMinorUpdate, false);
      service.build = 38;
      await notice.check();
      expect(notice.hasMinorUpdate, true);
      service.result = null;
      await notice.check();
      expect(notice.hasMinorUpdate, false);
      service.result = release('3.1.2', build: 37);
      await notice.check();
      expect(notice.available, isNull);
      service.result = release('4.0.0', build: 40);
      await notice.check();
      expect(notice.available!.isMajorRelease, true);
      expect(notice.hasMinorUpdate, false);
      service.sdk = 23;
      await notice.check();
      expect(notice.available, isNull);
    },
  );

  test(
    'a first failed check cannot invent an update; concurrent checks are coalesced',
    () async {
      final service = NoticeService()..fail = true;
      final notice = AppUpdateNotice(service: service, supported: true);
      addTearDown(notice.dispose);
      await notice.check();
      expect(notice.available, isNull);
      service.fail = false;
      service.pending = Completer<AppRelease?>();
      final a = notice.check(), b = notice.check();
      expect(service.calls, 2);
      service.pending!.complete(release('3.1.1'));
      await Future.wait([a, b]);
      expect(notice.hasMinorUpdate, true);
      expect(service.calls, 2);
    },
  );

  test(
    'manual result and disposal cannot be overwritten by an old automatic request',
    () async {
      final service = NoticeService()..pending = Completer<AppRelease?>();
      final notice = AppUpdateNotice(service: service, supported: true);
      final pending = notice.check();
      notice.observe(null, currentBuild: 39, sdk: 35);
      service.pending!.complete(release('3.1.0'));
      await pending;
      expect(notice.available, isNull);
      service.pending = Completer<AppRelease?>();
      final pending2 = notice.check();
      notice.dispose();
      service.pending!.complete(release('4.0.0'));
      await pending2;
      expect(service.closed, true);
      expect(notice.available, isNull);
    },
  );

  testWidgets(
    'minor update stays out of home and shows a red dot below contact; viewing does not clear it',
    (tester) async {
      final controller = AppController(NoticeSettings());
      await controller.initialize();
      final notice = AppUpdateNotice(supported: false);
      notice.observe(release('3.1.0'), currentBuild: 38, sdk: 35);
      await tester.pumpWidget(
        MaterialApp(
          home: AppShell(controller: controller, updateNotice: notice),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.byKey(const ValueKey('home-ai-image-button')), findsNothing);
      await tester.tap(find.text('我的'));
      await tester.pumpAndSettle();
      final about = find.byKey(const ValueKey('profile-about-entry'));
      await tester.scrollUntilVisible(about, 250);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('profile-update-dot')), findsOneWidget);
      expect(
        tester.getTopLeft(find.text('联系开发者')).dy,
        lessThan(tester.getTopLeft(about).dy),
      );
      await tester.tap(about);
      await tester.pumpAndSettle();
      expect(find.text('检查更新'), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('profile-update-dot')), findsOneWidget);
      notice.observe(release('3.1.0'), currentBuild: 39, sdk: 35);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('profile-update-dot')), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
      notice.dispose();
      controller.dispose();
    },
  );

  testWidgets(
    'major prompt waits for home, dismisses once per build and does not interrupt background',
    (tester) async {
      final controller = AppController(NoticeSettings());
      await controller.initialize();
      final notice = AppUpdateNotice(supported: false);
      await tester.pumpWidget(
        MaterialApp(
          home: AppShell(controller: controller, updateNotice: notice),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('我的'));
      await tester.pumpAndSettle();
      notice.observe(release('3.0.0'), currentBuild: 38, sdk: 35);
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      await tester.tap(find.text('首页'));
      await tester.pumpAndSettle();
      expect(find.text('发现新版本 3.0.0'), findsOneWidget);
      await tester.tap(find.text('稍后再说'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('我的'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('首页'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      await tester.tap(find.byKey(const ValueKey('home-weather-bar')));
      await tester.pumpAndSettle();
      notice.observe(release('4.0.0', build: 40), currentBuild: 38, sdk: 35);
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('发现新版本 4.0.0'), findsOneWidget);
      await tester.tap(find.text('稍后再说'));
      await tester.pumpAndSettle();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      notice.observe(release('5.0.0', build: 41), currentBuild: 38, sdk: 35);
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(find.text('发现新版本 5.0.0'), findsOneWidget);
      await tester.tap(find.text('稍后再说'));
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox.shrink());
      notice.dispose();
      controller.dispose();
    },
  );
}
