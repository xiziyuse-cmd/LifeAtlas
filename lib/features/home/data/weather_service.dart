import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:geolocator/geolocator.dart';
import 'package:timezone/timezone.dart' as tz;
import '../../../core/network/mobile_api.dart';
import '../../../core/database/date_key_codec.dart';
import '../../../core/database/outfit_weather_integrity.dart';
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

  Future<HourlyForecast> getHourlyWeather({
    bool forceRefresh = false,
    Map<String, dynamic>? citySnapshot,
  }) async {
    final city = citySnapshot ?? await selectedCity();
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
    final matches = await searchCities(
      '${position.longitude.toStringAsFixed(2)},${position.latitude.toStringAsFixed(2)}',
    );
    return matches
        .map((city) => {...city, 'selectionSource': 'location'})
        .toList();
  }

  @override
  Future<WeatherModel> getCurrentWeather({
    double? latitude,
    double? longitude,
    bool forceRefresh = false,
    Map<String, dynamic>? citySnapshot,
  }) async {
    final city = citySnapshot ?? await selectedCity();
    if (city == null) {
      throw StateError('请选择城市，或使用当前位置');
    }
    try {
      final data = await api.call('weather', {
        'city': city,
        'forceRefresh': forceRefresh,
      });
      final weather = WeatherModel.fromJson(data);
      final today = tz.TZDateTime.from(
        clock(),
        HourlyForecast.location(city['tz'] as String),
      );
      if (weather.date != DateKeyCodec.encode(today)) {
        throw const FormatException('天气日期与城市当天不一致');
      }
      final activeCity = await selectedCity();
      if (activeCity?['id'] != city['id'] || activeCity?['tz'] != city['tz']) {
        throw StateError('城市已切换，请重新获取天气');
      }
      await api.saveSetting('weather_cache_${city['id']}', {
        ...data,
        'cityId': city['id'],
        'tz': city['tz'],
      });
      final db = await api.database.database;
      await db.transaction((tx) async {
        final selections = await tx.query(
          'app_settings',
          where: 'setting_key = ?',
          whereArgs: ['weather_city'],
        );
        if (selections.isNotEmpty) {
          final selection =
              jsonDecode(selections.single['setting_value'] as String) as Map;
          if (selection['id'] != city['id'] || selection['tz'] != city['tz']) {
            throw StateError('城市已切换，请重新获取天气');
          }
        }
        await tx.insert('weather_records', {
          'record_date': weather.date,
          'region': weather.region,
          'weather_type': weather.status,
          'current_temperature': weather.currentTemperature,
          'min_temperature': weather.minTemperature,
          'max_temperature': weather.maxTemperature,
          'recorded_at': weather.fetchedAt,
          'data_source': 'qweather:current+forecast-range',
          'weather_city_id': city['id'],
          'weather_zone': city['tz'],
        }, conflictAlgorithm: ConflictAlgorithm.replace);
        await tx.update(
          'daily_outfit_records',
          {
            'weather_type': weather.status,
            'min_temperature': weather.minTemperature,
            'max_temperature': weather.maxTemperature,
            'weather_status': 'verified',
            'weather_source': 'qweather:current+forecast-range',
            'weather_city_id': city['id'],
            'weather_zone': city['tz'],
            'weather_fetched_at': weather.fetchedAt,
            'temperature_applied_at': clock().toUtc().toIso8601String(),
          },
          where:
              "record_date = ? AND (weather_status = 'missing' OR (weather_status = 'verified' AND weather_city_id = ? AND weather_source = 'qweather:current+forecast-range'))",
          whereArgs: [weather.date, city['id']],
        );
        await rebuildOutfitTemperatures(tx);
      });
      return weather;
    } catch (error) {
      final active = await selectedCity();
      if (active?['id'] != city['id'] || active?['tz'] != city['tz']) rethrow;
      final cache = await api.setting('weather_cache_${city['id']}');
      if (cache != null) {
        final raw = Map<String, dynamic>.from(cache as Map);
        if (raw['cityId'] != city['id'] || raw['tz'] != city['tz']) rethrow;
        final cached = WeatherModel.fromJson(
          raw,
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
