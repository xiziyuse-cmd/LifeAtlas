import 'package:flutter_test/flutter_test.dart';
import 'package:lifeatlas/core/network/mobile_api.dart';
import 'package:lifeatlas/features/home/data/weather_service.dart';
import 'package:lifeatlas/features/home/domain/hourly_weather.dart';

Map<String, dynamic> forecast({
  String id = 'a',
  String zone = 'Asia/Shanghai',
}) => {
  'cityId': id,
  'tz': zone,
  'fetchedAt': '2026-11-02T15:30:00Z',
  'hours': [
    for (final time in [
      '2026-11-02T23:00:00+08:00',
      '2026-11-03T00:00:00+08:00',
      '2026-11-03T01:00:00+08:00',
    ])
      {'time': time, 'icon': '☀️', 'status': '晴', 'temperature': 20},
  ],
};

class WeatherApi extends MobileApi {
  final values = <String, Object?>{
    'weather_city': {'id': 'a', 'tz': 'Asia/Shanghai'},
  };
  int calls = 0;
  bool fail = false;
  bool? forced;
  @override
  Future<Object?> setting(String key) async => values[key];
  @override
  Future<void> saveSetting(String key, Object? value) async {
    values[key] = value;
  }

  @override
  Future<Map<String, dynamic>> call(
    String action, [
    Map<String, Object?> data = const {},
  ]) async {
    calls++;
    forced = data['forceRefresh'] as bool?;
    if (fail) throw StateError('服务权限不足');
    return forecast(id: (data['city'] as Map)['id'] as String);
  }
}

void main() {
  test(
    'city midnight grouping ignores device zone and excludes expired hours',
    () {
      final value = HourlyForecast.fromJson(forecast());
      expect(value.day(0, DateTime.parse('2026-11-02T15:30Z')), hasLength(1));
      expect(value.day(1, DateTime.parse('2026-11-02T15:30Z')), hasLength(2));
      expect(value.day(0, DateTime.parse('2026-11-02T16:30Z')), hasLength(2));
    },
  );
  test('DST repeated hour preserves both instants and correct city date', () {
    final json = forecast(zone: 'America/New_York');
    json['hours'] = [
      for (final time in [
        '2026-11-01T01:00:00-04:00',
        '2026-11-01T01:00:00-05:00',
      ])
        {'time': time, 'icon': '☁️', 'status': '多云', 'temperature': 10},
    ];
    final value = HourlyForecast.fromJson(json);
    expect(value.day(0, DateTime.parse('2026-11-01T04:00Z')), hasLength(2));
    expect(value.hours.map((h) => value.local(h.time).hour), [1, 1]);
  });
  test(
    'cache expiry, force refresh, failure fallback, city isolation and corrupted cache',
    () async {
      final api = WeatherApi();
      var now = DateTime.parse('2026-11-02T15:30Z');
      final service = QWeatherService(api: api, clock: () => now);
      await service.getHourlyWeather();
      await service.getHourlyWeather();
      expect(api.calls, 1);
      await service.getHourlyWeather(forceRefresh: true);
      expect(api.forced, isTrue);
      expect(api.calls, 2);
      now = now.add(const Duration(minutes: 16));
      api.fail = true;
      expect((await service.getHourlyWeather()).cached, isTrue);
      await service.selectCity({'id': 'b', 'tz': 'Asia/Shanghai'});
      await expectLater(service.getHourlyWeather(), throwsStateError);
      await service.selectCity({'id': 'a', 'tz': 'Asia/Shanghai'});
      now = now.add(const Duration(days: 3));
      await expectLater(service.getHourlyWeather(), throwsStateError);
      now = DateTime.parse('2026-11-02T15:30Z');
      api.fail = false;
      api.values['weather_hourly_v1_a'] = {'broken': true};
      expect((await service.getHourlyWeather()).cityId, 'a');
    },
  );
}
