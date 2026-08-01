import '../domain/weather_model.dart';

abstract interface class WeatherService {
  Future<WeatherModel> getCurrentWeather({double? latitude, double? longitude});
}

class MockWeatherService implements WeatherService {
  const MockWeatherService();

  @override
  Future<WeatherModel> getCurrentWeather({
    double? latitude,
    double? longitude,
  }) async {
    return const WeatherModel(
      icon: '☁️',
      status: '多云',
      currentTemperature: 26,
      minTemperature: 22,
      maxTemperature: 30,
      isSimulated: true,
    );
  }
}
