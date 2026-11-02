import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeatlas/features/home/data/weather_service.dart';
import 'package:lifeatlas/features/home/domain/weather_model.dart';
import 'package:lifeatlas/features/home/domain/hourly_weather.dart';
import 'package:lifeatlas/features/home/presentation/weather_detail_page.dart';
import 'package:lifeatlas/features/home/presentation/widgets/home_weather_card.dart';
import 'hourly_weather_test.dart' show forecast;

class LayoutService extends QWeatherService {
  LayoutService() : super(clock: () => DateTime.parse('2026-11-02T15:30Z'));
  String city = '成都';
  String source = 'manual';
  @override
  Future<Map<String, dynamic>?> selectedCity() async => {
    'id': city,
    'name': city,
    'region': city,
    'tz': 'Asia/Shanghai',
    'selectionSource': source,
  };
  @override
  Future<List<Map<String, dynamic>>> locate() async => [
    {'id': 'b', 'name': '上海', 'region': '上海', 'selectionSource': 'location'},
  ];
  bool fail = false;
  bool forcedCurrent = false, forcedHourly = false;
  Completer<WeatherModel>? pending;
  WeatherModel get value => WeatherModel(
    icon: '☀️',
    status: '晴',
    currentTemperature: 20,
    minTemperature: 15,
    maxTemperature: 25,
    region: city,
    date: '2026-11-02',
    fetchedAt: '2026-11-02T15:30Z',
    source: '和风天气',
  );
  @override
  Future<WeatherModel> getCurrentWeather({
    double? latitude,
    double? longitude,
    bool forceRefresh = false,
    Map<String, dynamic>? citySnapshot,
  }) async {
    forcedCurrent = forceRefresh;
    if (pending != null) return pending!.future;
    if (fail) throw StateError('无网络');
    return value;
  }

  @override
  Future<HourlyForecast> getHourlyWeather({
    bool forceRefresh = false,
    Map<String, dynamic>? citySnapshot,
  }) async {
    forcedHourly = forceRefresh;
    if (fail) throw StateError('无小时权限');
    return HourlyForecast.fromJson(forecast());
  }

  @override
  Future<List<Map<String, dynamic>>> searchCities(String query) async => [
    {'id': 'b', 'name': '上海', 'region': '上海'},
  ];
  @override
  Future<void> selectCity(Map<String, dynamic> value) async {
    city = value['name'] as String;
    source = value['selectionSource'] as String? ?? 'manual';
  }
}

void main() {
  testWidgets(
    'search is right of field; location marker survives refresh and manual selection clears it',
    (tester) async {
      final service = LayoutService();
      await tester.pumpWidget(
        MaterialApp(home: WeatherDetailPage(service: service)),
      );
      await tester.pumpAndSettle();
      expect(
        tester.getCenter(find.byTooltip('搜索城市')).dx,
        greaterThan(tester.getCenter(find.byType(TextField)).dx),
      );
      await tester.tap(find.text('使用当前位置'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('上海').first);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('weather-location-indicator')),
        findsOneWidget,
      );
      expect(find.text('上海 · 当地时间'), findsOneWidget);
      await tester.tap(find.text('刷新'));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('weather-location-indicator')),
        findsOneWidget,
      );
      await tester.tap(find.byTooltip('搜索城市'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('上海').first);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('weather-location-indicator')),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'home hides time and recommendations but keeps visible attribution',
    (tester) async {
      final service = LayoutService();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HomeWeatherCard(
              weather: service.value,
              isLoading: false,
              recommendationNames: const ['衬衫'],
            ),
          ),
        ),
      );
      expect(find.text('来源：和风天气'), findsOneWidget);
      expect(find.textContaining('获取'), findsNothing);
      expect(find.textContaining('推荐'), findsNothing);
      expect(find.text('20℃'), findsOneWidget);
    },
  );
  testWidgets(
    'narrow large text, bottom refresh, two day scrolls and independent errors',
    (tester) async {
      tester.view.physicalSize = const Size(360, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final service = LayoutService();
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(1.5)),
            child: child!,
          ),
          home: WeatherDetailPage(service: service),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.textContaining('天气数据由'), findsNothing);
      final refresh = find.text('刷新');
      await tester.ensureVisible(refresh);
      expect(
        tester.getTopLeft(refresh).dx,
        greaterThan(tester.getTopLeft(find.text('来源：和风天气')).dx),
      );
      await tester.tap(refresh);
      await tester.pumpAndSettle();
      expect(service.forcedCurrent, isTrue);
      expect(service.forcedHourly, isTrue);
      await tester.ensureVisible(find.byKey(const ValueKey('hourly-day-1')));
      expect(find.text('今天'), findsOneWidget);
      expect(find.text('明天'), findsOneWidget);
      service.fail = true;
      await tester.ensureVisible(refresh);
      await tester.tap(refresh);
      await tester.pumpAndSettle();
      expect(find.textContaining('无小时权限'), findsOneWidget);
      expect(find.text('成都'), findsOneWidget);
      expect(find.text('成都 · 当地时间'), findsOneWidget);
      expect(find.textContaining('Asia/Shanghai'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'failed city change clears old city; disposal ignores pending result',
    (tester) async {
      final service = LayoutService();
      await tester.pumpWidget(
        MaterialApp(home: WeatherDetailPage(service: service)),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('搜索城市'));
      await tester.pumpAndSettle();
      service.fail = true;
      await tester.tap(find.text('上海').first);
      await tester.pumpAndSettle();
      expect(find.text('成都'), findsNothing);
      service.pending = Completer<WeatherModel>();
      await tester.tap(find.text('刷新'));
      await tester.pump();
      await tester.pumpWidget(const SizedBox());
      service.pending!.complete(service.value);
      await tester.pump();
      expect(tester.takeException(), isNull);
    },
  );
}
