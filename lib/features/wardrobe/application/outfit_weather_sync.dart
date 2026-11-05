import '../../../core/database/date_key_codec.dart';
import '../../home/data/weather_service.dart';
import '../data/wardrobe_repository.dart';

/// Called only after the user saves an outfit, not by passive weather refresh.
class OutfitWeatherSync {
  OutfitWeatherSync({
    required this.repository,
    QWeatherService? weather,
    DateTime Function()? clock,
  }) : weather = weather ?? QWeatherService(),
       clock = clock ?? DateTime.now;
  final WardrobeRepository repository;
  final QWeatherService weather;
  final DateTime Function() clock;

  Future<void> sync(DateTime date) async {
    if (DateKeyCodec.encode(date) != DateKeyCodec.encode(clock())) return;
    if (await repository.getDailyOutfit(date) == null) return;
    final city = await weather.selectedCity();
    if (city == null) throw StateError('请选择天气城市');
    final snapshot = await weather.getCurrentWeather(citySnapshot: city);
    if (snapshot.isSimulated || snapshot.date != DateKeyCodec.encode(date)) {
      throw StateError('暂无记录当天的有效天气');
    }
    // Applies a validated cache too; passive refresh intentionally leaves old
    // pending records alone, whereas this action explicitly records today.
    await repository.confirmRecordedWeather(
      date: date,
      cityId: city['id'] as String,
      zone: city['tz'] as String,
      minimum: snapshot.minTemperature,
      maximum: snapshot.maxTemperature,
      weatherType: snapshot.status,
      fetchedAt: snapshot.fetchedAt,
    );
  }
}
