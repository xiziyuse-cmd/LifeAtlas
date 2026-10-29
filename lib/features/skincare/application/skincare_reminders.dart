import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../data/skincare_repository.dart';
import '../domain/skincare_models.dart';
import '../domain/skincare_rules.dart';

class SkincareReminders {
  SkincareReminders(this.repository);
  final SkincareRepository repository;
  final plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;
  Future<void> _queue = Future.value();
  void Function(String)? onTap;
  String? launchPeriod;
  bool get supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
  Future<void> initialize() async {
    if (_ready || !supported) return;
    tzdata.initializeTimeZones();
    final zone = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(zone.identifier));
    await plugin.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
      onDidReceiveNotificationResponse: (r) {
        if (r.payload != null) onTap?.call(r.payload!);
      },
    );
    final launch = await plugin.getNotificationAppLaunchDetails();
    if (launch?.didNotificationLaunchApp == true) {
      launchPeriod = launch?.notificationResponse?.payload;
    }
    _ready = true;
  }

  Future<bool> requestPermission() async {
    if (!supported) return false;
    await initialize();
    return await plugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >()
            ?.requestNotificationsPermission() ??
        false;
  }

  Future<void> reschedule({bool enabled = true}) {
    final result = _queue
        .catchError((Object _) {})
        .then((_) => _reschedule(enabled: enabled));
    _queue = result;
    return result;
  }

  Future<void> _reschedule({required bool enabled}) async {
    if (!supported) return;
    await initialize();
    for (var i = 0; i < 56; i++) {
      await plugin.cancel(8100 + i);
    }
    if (!enabled) return;
    final zone = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(zone.identifier));
    final settings = object(await repository.setting('reminders') ?? {});
    final plan = await repository.activePlan();
    final profile = await repository.profile();
    if (plan == null ||
        profile == null ||
        SkincareRules.validate(
          plan,
          await repository.products(),
          profile,
        ).isNotEmpty) {
      return;
    }
    final now = tz.TZDateTime.now(tz.local);
    for (var day = 0; day < 28; day++) {
      for (var n = 0; n < 2; n++) {
        final period = n == 0 ? 'am' : 'pm';
        if (settings['${period}Enabled'] != true) continue;
        final minute =
            settings['${period}Minute'] as int? ?? (n == 0 ? 480 : 1290);
        final when = tz.TZDateTime(
          tz.local,
          now.year,
          now.month,
          now.day + day,
          minute ~/ 60,
          minute % 60,
        );
        if (!when.isAfter(now)) continue;
        final steps = plan.steps(when, period);
        if (steps.isEmpty ||
            (await repository.execution(skinDate(when), period))?.finished ==
                true) {
          continue;
        }
        await plugin.zonedSchedule(
          8100 + day * 2 + n,
          n == 0 ? '早间护理' : '晚间护理',
          steps.map((s) => s.name).join(' → '),
          when,
          const NotificationDetails(
            android: AndroidNotificationDetails(
              'skincare',
              '护肤提醒',
              channelDescription: '每天的早晚护理计划',
              importance: Importance.defaultImportance,
            ),
          ),
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          payload: period,
        );
      }
    }
  }
}
