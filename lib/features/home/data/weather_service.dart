import 'package:geolocator/geolocator.dart';
import 'package:timezone/timezone.dart' as tz;
import '../../../core/network/mobile_api.dart';
import '../../../core/database/date_key_codec.dart';
import '../domain/weather_model.dart';
import '../domain/hourly_weather.dart';

abstract interface class WeatherService {
  Future<WeatherModel> getCurrentWeather({double? latitude, double? longitude});
}

class QWeatherService implements WeatherService {
  QWeatherService({MobileApi? api, DateTime Function()? clock})
    : api = api ?? MobileApi.shared,
      clock = clock ?? DateTime.now;
  final MobileApi api;
  final DateTime Function() clock;

  Future<HourlyForecast> getHourlyWeather({bool forceRefresh = false}) async {
    final city = await selectedCity();
    if (city == null) throw StateError('请选择城市，或使用当前位置');
    final key = 'weather_hourly_v1_${city['id']}';
    HourlyForecast? cached;
    Map<String, dynamic>? saved;
    try {
      final raw = await api.setting(key);
      if (raw != null) {
        saved = Map<String, dynamic>.from(raw as Map);
        cached = HourlyForecast.fromJson(saved);
        if (cached.cityId != city['id'] || cached.zone != city['tz']) {
          cached = null;
        }
      }
    } catch (_) {
      /* A damaged cache must not prevent a network retry. */
    }
    if (!forceRefresh && cached != null && cached.fresh(clock())) return cached;
    try {
      final data = await api.call('weatherHourly', {
        'city': city,
        'forceRefresh': forceRefresh,
      });
      final result = HourlyForecast.fromJson(data);
      if (result.cityId != city['id'] ||
          result.zone != city['tz'] ||
          !result.usable(clock())) {
        throw const FormatException('暂无该城市的有效小时预报');
      }
      await api.saveSetting(key, data);
      return result;
    } catch (error) {
      if (cached != null && cached.usable(clock())) {
        return HourlyForecast.fromJson(
          saved!,
          cached: true,
          warning: error.toString().replaceFirst('Bad state: ', ''),
        );
      }
      rethrow;
    }
  }

  Future<Map<String, dynamic>?> selectedCity() async {
    final value = await api.setting('weather_city');
    return value == null ? null : Map<String, dynamic>.from(value as Map);
  }

  Future<List<Map<String, dynamic>>> searchCities(String query) async {
    final result = await api.call('cities', {'query': query});
    return (result['cities'] as List)
        .map((v) => Map<String, dynamic>.from(v as Map))
        .toList();
  }

  Future<void> selectCity(Map<String, dynamic> city) =>
      api.saveSetting('weather_city', city);
  Future<List<Map<String, dynamic>>> locate() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw StateError('请打开系统定位，或手动搜索城市');
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      throw StateError('未获定位授权，可手动搜索城市');
    }
    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.low,
        timeLimit: Duration(seconds: 20),
      ),
    );
    return searchCities(
      '${position.longitude.toStringAsFixed(2)},${position.latitude.toStringAsFixed(2)}',
    );
  }

  @override
  Future<WeatherModel> getCurrentWeather({
    double? latitude,
    double? longitude,
    bool forceRefresh = false,
  }) async {
    final city = await selectedCity();
    if (city == null) {
      throw StateError('请选择城市，或使用当前位置');
    }
    try {
      final data = await api.call('weather', {
        'city': city,
        'forceRefresh': forceRefresh,
      });
      final weather = WeatherModel.fromJson(data);
      await api.saveSetting('weather_cache_${city['id']}', data);
      final now = DateTime.now();
      if (weather.date == DateKeyCodec.encode(now)) {
        final db = await api.database.database;
        await db.rawInsert(
          'INSERT OR REPLACE INTO weather_records(record_date,region,weather_type,current_temperature,min_temperature,max_temperature,recorded_at,data_source) VALUES(?,?,?,?,?,?,?,?)',
          [
            weather.date,
            weather.region,
            weather.status,
            weather.currentTemperature,
            weather.minTemperature,
            weather.maxTemperature,
            weather.fetchedAt,
            'qweather:current+forecast-range',
          ],
        );
      }
      return weather;
    } catch (error) {
      final cache = await api.setting('weather_cache_${city['id']}');
      if (cache != null) {
        final cached = WeatherModel.fromJson(
          Map<String, dynamic>.from(cache as Map),
          cached: true,
          warning: error.toString().replaceFirst('Bad state: ', ''),
        );
        final zone = city['tz'] as String?;
        final today = zone == null
            ? clock()
            : tz.TZDateTime.from(clock(), HourlyForecast.location(zone));
        if (cached.date != DateKeyCodec.encode(today)) rethrow;
        return cached;
      }
      rethrow;
    }
  }
}

// Test-only fixture. The application uses QWeatherService.
class MockWeatherService implements WeatherService {
  const MockWeatherService();
  @override
  Future<WeatherModel> getCurrentWeather({
    double? latitude,
    double? longitude,
  }) async => const WeatherModel(
    icon: '☁️',
    status: '多云',
    currentTemperature: 26,
    minTemperature: 22,
    maxTemperature: 30,
    isSimulated: true,
  );
}
