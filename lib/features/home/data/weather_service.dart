import 'package:geolocator/geolocator.dart';
import '../../../core/network/mobile_api.dart';
import '../../../core/database/date_key_codec.dart';
import '../domain/weather_model.dart';

abstract interface class WeatherService {
  Future<WeatherModel> getCurrentWeather({double? latitude, double? longitude});
}

class QWeatherService implements WeatherService {
  QWeatherService({MobileApi? api}) : api = api ?? MobileApi.shared;
  final MobileApi api;
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
  }) async {
    final city = await selectedCity();
    if (city == null) {
      throw StateError('请选择城市，或使用当前位置');
    }
    try {
      final data = await api.call('weather', {'city': city});
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
        return WeatherModel.fromJson(
          Map<String, dynamic>.from(cache as Map),
          cached: true,
          warning: error.toString().replaceFirst('Bad state: ', ''),
        );
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
